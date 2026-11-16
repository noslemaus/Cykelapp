// Cykelbrygga — Bluetooth bridge between the trainer/heart-rate straps and the Godot game.
//
// Telemetry goes to the game as JSON over UDP 127.0.0.1:47010; commands come back on 127.0.0.1:47011.
// The bridge has no training logic: it only translates FTMS/Heart Rate packets to JSON and
// JSON commands ("erg", "sim", "spindown", "release") to FTMS control-point writes.
//
// Safety: if control was taken and the game stops talking for 5 s, the trainer is reset
// (FTMS opcode 0x01) so it never stays locked in ERG. After the game has spoken once and then
// stays silent for 60 s, the bridge exits. "--read-only" ignores every trainer write.
//
// Zwift Click (v2 pair, or v1): the bridge connects, sends the "RideOn" greeting the controllers
// wait for, decodes their key pad (message 0x23, protobuf field 1, a 0 bit = pressed) and sends
// each change to the game as {"t":"button","id":"v_vanster","down":true}. Nothing else is ever
// written to them. A Click v2 only reports buttons after it has been connected to the Zwift app
// within the last day. While the game says "controllersOnly" (pretend trainer in the game), the
// bridge leaves trainers and straps alone and only talks to the Clicks.
//
// Trainers: every device advertising FTMS (smart trainers) or Cycling Power (also power meters) is
// listed in the status ("trainers"). With "trainer": <id> in the game's commands the bridge only
// connects to that one; without it, it takes the first smart trainer, and a device with only
// Cycling Power when no smart trainer has shown up within 5 s.
import AppKit
import CoreBluetooth
import Foundation


let ftmsService = CBUUID(string: "1826")
let cyclingPowerService = CBUUID(string: "1818")
let heartRateService = CBUUID(string: "180D")
let indoorBikeData = CBUUID(string: "2AD2")
let cyclingPowerMeasurement = CBUUID(string: "2A63")
let heartRateMeasurement = CBUUID(string: "2A37")
let ftmsControlPoint = CBUUID(string: "2AD9")
let ftmsStatus = CBUUID(string: "2ADA")          // Fitness Machine Status: spin down progress
let ftmsFeature = CBUUID(string: "2ACC")         // Fitness Machine Feature: can it spin down?
let clickService = CBUUID(string: "FC82")
let zwiftControllerService = CBUUID(string: "00000001-19CA-4651-86E5-FA29DCDD09D1")
let clickAsync = CBUUID(string: "00000002-19CA-4651-86E5-FA29DCDD09D1")
let clickSyncRx = CBUUID(string: "00000003-19CA-4651-86E5-FA29DCDD09D1")
let clickSyncTx = CBUUID(string: "00000004-19CA-4651-86E5-FA29DCDD09D1")
let zwiftCompanyID: UInt16 = 0x094A
let rideOn: [UInt8] = [0x52, 0x69, 0x64, 0x65, 0x4F, 0x6E]
/// Key pad bits of the Click v2 pair (left: arrows and minus, right: A B Y Z and plus).
let clickButtons: [(UInt32, String)] = [
    (0x00001, "v_vanster"), (0x00002, "v_upp"), (0x00004, "v_hoger"), (0x00008, "v_ner"), (0x00100, "v_vaxla"),
    (0x00010, "h_a"), (0x00020, "h_b"), (0x00040, "h_y"), (0x00080, "h_z"), (0x01000, "h_vaxla"),
]

/// One Zwift Click unit.
final class Click {
    let peripheral: CBPeripheral
    let isV2: Bool
    var pressed: UInt32 = 0
    var greeted = false
    var reportedButtons = false
    var lockedChallenge = false
    var connectedAt = Date()
    init(peripheral: CBPeripheral, isV2: Bool) {
        self.peripheral = peripheral
        self.isV2 = isV2
    }
}

/// Field 1 varint of a protobuf message (the key pad map), or nil.
func protobufField1(_ bytes: ArraySlice<UInt8>) -> UInt64? {
    var i = bytes.startIndex
    func varint() -> UInt64? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while i < bytes.endIndex {
            let b = bytes[i]
            i += 1
            value |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { return value }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }
    while i < bytes.endIndex {
        guard let key = varint() else { return nil }
        switch key & 7 {
        case 0:
            guard let v = varint() else { return nil }
            if key >> 3 == 1 { return v }
        case 1: i += 8
        case 2:
            guard let len = varint() else { return nil }
            i += Int(len)
        case 5: i += 4
        default: return nil
        }
    }
    return nil
}

let telemetryPort: UInt16 = 47010
let commandPort: UInt16 = 47011

struct Options {
    var readOnly = false
    var logPath: String?
    init(_ args: [String]) {
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--read-only": readOnly = true
            case "--log" where i + 1 < args.count: logPath = args[i + 1]; i += 1
            default: break
            }
            i += 1
        }
    }
}

let options = Options(CommandLine.arguments)
let startTime = Date()
let logHandle: FileHandle? = options.logPath.flatMap { path in
    FileManager.default.createFile(atPath: path, contents: nil)
    return FileHandle(forWritingAtPath: path)
}

func log(_ message: String) {
    let line = String(format: "[%6.1fs] ", Date().timeIntervalSince(startTime)) + message + "\n"
    logHandle?.write(line.data(using: .utf8)!)
    FileHandle.standardError.write(line.data(using: .utf8)!)
}

struct ByteReader {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = [UInt8](data) }
    var remaining: Int { bytes.count - offset }
    mutating func u8() -> UInt8? {
        guard remaining >= 1 else { return nil }
        defer { offset += 1 }
        return bytes[offset]
    }
    mutating func u16() -> UInt16? {
        guard remaining >= 2 else { return nil }
        defer { offset += 2 }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }
    mutating func s16() -> Int16? { u16().map { Int16(bitPattern: $0) } }
    mutating func skip(_ n: Int) { offset = min(bytes.count, offset + n) }
}

/// A number from a game command, or `fallback`, kept between `low` and `high` (NaN gives `fallback`).
func bounded(_ value: Any?, _ fallback: Double, _ low: Double, _ high: Double) -> Double {
    guard let v = (value as? NSNumber)?.doubleValue, v.isFinite else { return fallback }
    return min(max(v, low), high)
}

func le16(_ value: Int) -> [UInt8] {
    let v = UInt16(bitPattern: Int16(clamping: value))
    return [UInt8(v & 0xFF), UInt8(v >> 8)]
}

/// UDP link to the game over one plain socket bound to the command port: commands are read from
/// any sender, telemetry is sent to the game's port. (Network.framework's NWListener dropped
/// datagrams coming from the same port its outgoing connection targeted, so it is not used.)
final class GameLink {
    private var fd: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var gameAddress = sockaddr_in()
    var onCommand: (([String: Any]) -> Void)?

    private static func loopback(port: UInt16) -> sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        return addr
    }

    func start() {
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        var commandAddress = GameLink.loopback(port: commandPort)
        let bound = withUnsafePointer(to: &commandAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bound != 0 {
            log("FEL: kommandoporten \(commandPort) är upptagen. Kör redan en annan Cykelbrygga?")
        }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        gameAddress = GameLink.loopback(port: telemetryPort)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in self?.drain() }
        source.resume()
        readSource = source
    }

    private func drain() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count <= 0 { break }
            if let object = try? JSONSerialization.jsonObject(with: Data(buffer[0..<count])) as? [String: Any] {
                onCommand?(object)
            }
        }
    }

    func send(_ object: [String: Any]) {
        guard fd >= 0, let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        data.withUnsafeBytes { raw in
            withUnsafePointer(to: &gameAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = sendto(fd, raw.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}

final class Bridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let link = GameLink()
    private var central: CBCentralManager!
    private var trainer: CBPeripheral?
    private var trainerState = "söker"
    private var controlPoint: CBCharacteristic?
    private var straps: [UUID: CBPeripheral] = [:]
    private var clicks: [UUID: Click] = [:]
    private var buttonsDown: UInt32 = 0          // union of what every Click reports as pressed
    private var controllersOnly = false          // the game rides the pretend trainer: Clicks only

    // Trainers seen while scanning, and the one the player picked (nil = the first smart trainer).
    private struct SeenTrainer { let peripheral: CBPeripheral; let name: String; let smart: Bool; let rssi: Int }
    private var seenTrainers: [UUID: SeenTrainer] = [:]
    private var wantedTrainer: UUID?
    private var scanStarted = Date()

    // Latest values.
    private var power: Int?
    private var cadence: Double?
    private var speedKmh: Double?
    private var strapHR: (bpm: Int, at: Date, name: String)?
    private var relayHR: Int?

    // Spin down (calibration): nil = not known yet, then what the trainer's FTMS features say.
    private var spindownSupported: Bool?
    private var spindownActive = false

    // Control state.
    private var control = "ingen"            // ingen | begärd | given | nekad
    private var pendingCommand: [UInt8]?
    private var lastGameMessage: Date?

    func start() {
        log("Cykelbrygga startar\(options.readOnly ? " (skrivskyddad: skriver aldrig till trainern)" : "").")
        link.onCommand = { [weak self] in self?.handle($0) }
        link.start()
        central = CBCentralManager(delegate: self, queue: nil)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: Game commands

    private func handle(_ command: [String: Any]) {
        if lastGameMessage == nil { log("Spelet har anslutit") }
        lastGameMessage = Date()
        if let name = command["cmd"] as? String, name != "ping" { log("Kommando från spelet: \(name)") }
        if let only = command["controllersOnly"] as? Bool, only != controllersOnly {
            setControllersOnly(only)
        }
        if let id = command["trainer"] as? String {
            setWantedTrainer(id.isEmpty ? nil : UUID(uuidString: id))
        }
        switch command["cmd"] as? String {
        case "erg":
            let watts = (command["watts"] as? NSNumber)?.intValue ?? 0
            submit([0x05] + le16(max(0, min(2000, watts))), label: "ERG \(watts) W")
        case "sim":
            // Every value is kept within what FTMS can carry before it becomes an integer: Int() of a
            // huge or non-finite Double would stop the bridge.
            let grade = bounded(command["grade"], 0, -40, 40)          // percent
            let crr = bounded(command["crr"], 0.004, 0, 0.025)
            let cw = bounded(command["cw"], 0.51, 0, 2.55)              // kg/m
            let wind = bounded(command["wind"], 0, -30, 30)             // m/s
            let bytes: [UInt8] = [0x11] + le16(Int((wind * 1000).rounded())) + le16(Int((grade * 100).rounded()))
                + [UInt8(clamping: Int((crr * 10000).rounded())), UInt8(clamping: Int((cw * 100).rounded()))]
            submit(bytes, label: String(format: "SIM %.1f %%", grade))
        case "spindown":
            // FTMS Spin Down Control (0x13, start): the trainer answers with the speed to pedal up to,
            // then reports through Fitness Machine Status when to stop and how it went.
            guard trainer != nil, controlPoint != nil else {
                link.send(["t": "spindown", "state": "fel", "reason": "ingen trainer"])
                return
            }
            spindownActive = true
            link.send(["t": "spindown", "state": "begärd"])
            submit([0x13, 0x01], label: "kalibrering")
        case "release":
            release(reason: "spelet bad om det")
        case "quit":
            release(reason: "spelet avslutas")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.quit() }
        default:
            break  // "ping" and unknown commands only refresh the watchdog
        }
    }

    /// Pretend trainer in the game: let go of the trainer and straps and only keep the Clicks.
    /// Real trainer again: look for it as usual.
    private func setControllersOnly(_ only: Bool) {
        controllersOnly = only
        log(only ? "Bara handkontroller (spelet kör låtsastrainern)." : "Söker trainer och pulsband igen.")
        if only {
            release(reason: "spelet kör låtsastrainern")
            if let trainer { central.cancelPeripheralConnection(trainer) }
            for strap in straps.values { central.cancelPeripheralConnection(strap) }
        }
        scan()
    }

    /// The player picked a trainer (or "the first one found" again): let go of another one.
    private func setWantedTrainer(_ id: UUID?) {
        guard id != wantedTrainer else { return }
        wantedTrainer = id
        log("Vald trainer: \(id.flatMap { seenTrainers[$0]?.name } ?? (id == nil ? "första som hittas" : "inte sedd än"))")
        if let trainer, let id, trainer.identifier != id {
            release(reason: "byter trainer")
            central.cancelPeripheralConnection(trainer)
            forget(trainer)
        }
        pickTrainer()
    }

    /// Connect to the picked trainer once it has been seen, or else to the best one on offer.
    private func pickTrainer() {
        guard trainer == nil, !controllersOnly, central.state == .poweredOn else { return }
        var choice: SeenTrainer?
        if let wanted = wantedTrainer {
            choice = seenTrainers[wanted]
        } else {
            // A power meter on the bike also has Cycling Power: wait a moment for a smart trainer.
            choice = seenTrainers.values.filter { $0.smart }.max { $0.rssi < $1.rssi }
            if choice == nil, Date().timeIntervalSince(scanStarted) > 5 {
                choice = seenTrainers.values.max { $0.rssi < $1.rssi }
            }
        }
        guard let choice else { return }
        trainer = choice.peripheral
        trainerState = "ansluter"
        choice.peripheral.delegate = self
        log("Ansluter till trainer \(choice.name)")
        central.connect(choice.peripheral)
    }

    private func scan() {
        guard central.state == .poweredOn else { return }
        scanStarted = Date()
        central.scanForPeripherals(withServices: controllersOnly ? [clickService]
            : [ftmsService, cyclingPowerService, heartRateService, clickService])
    }

    /// Queue a control-point write; take control first if needed. Only the latest command is kept.
    private func submit(_ bytes: [UInt8], label: String) {
        guard !options.readOnly, !controllersOnly else { return }
        pendingCommand = bytes
        guard let trainer, let controlPoint else { return }
        switch control {
        case "given":
            flushPending()
        case "begärd":
            break
        default:
            log("Begär kontroll över trainern (\(label))")
            control = "begärd"
            trainer.writeValue(Data([0x00]), for: controlPoint, type: .withResponse)
        }
    }

    private func flushPending() {
        guard let bytes = pendingCommand, let trainer, let controlPoint else { return }
        pendingCommand = nil
        trainer.writeValue(Data(bytes), for: controlPoint, type: .withResponse)
    }

    /// FTMS reset (0x01) puts the trainer back to its default free-running state.
    private func release(reason: String) {
        pendingCommand = nil
        guard control == "given" || control == "begärd", let trainer, let controlPoint else { control = "ingen"; return }
        log("Släpper trainern: \(reason)")
        trainer.writeValue(Data([0x01]), for: controlPoint, type: .withResponse)
        control = "ingen"
    }

    private func tick() {
        // macOS shows its question about Bluetooth and the bridge waits for the answer.
        if central.state == .unknown, CBManager.authorization == .notDetermined {
            trainerState = "väntar på Bluetooth-behörighet"
        }
        pickTrainer()
        if let last = lastGameMessage {
            let silence = Date().timeIntervalSince(last)
            if silence > 5 && control != "ingen" { release(reason: "spelet har varit tyst i 5 s") }
            if silence > 60 { log("Spelet har varit tyst i 60 s, avslutar."); quit() }
        }
        let ready = clicks.values.filter { $0.greeted }
        let locked = ready.contains { !$0.reportedButtons && ($0.lockedChallenge || Date().timeIntervalSince($0.connectedAt) > 20) }
        link.send([
            "t": "status",
            "trainer": trainer.map { seenTrainers[$0.identifier]?.name ?? $0.name ?? "trainer" } ?? NSNull(),
            "trainerId": trainer?.identifier.uuidString ?? NSNull(),
            "trainers": seenTrainers.values.sorted { $0.name < $1.name }.map {
                ["id": $0.peripheral.identifier.uuidString, "name": $0.name, "smart": $0.smart] },
            "trainerState": trainerState,
            "hr": strapHR?.name ?? (relayHR != nil ? "via trainern" : NSNull()),
            "control": control,
            "readOnly": options.readOnly,
            "clicks": ready.count,
            "clicksLocked": locked && !ready.contains { $0.reportedButtons },
            "controllersOnly": controllersOnly,
            "spindown": spindownSupported.map { $0 as Any } ?? NSNull(),
        ])
    }

    private func quit() {
        central?.stopScan()
        if let trainer { central.cancelPeripheralConnection(trainer) }
        for strap in straps.values { central.cancelPeripheralConnection(strap) }
        for click in clicks.values { central.cancelPeripheralConnection(click.peripheral) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exit(0) }
    }

    // MARK: Bluetooth

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("Bluetooth på, söker trainer, pulsband och Zwift Click.")
            if trainer == nil { trainerState = "söker" }
            scan()
        case .unauthorized:
            trainerState = "ingen Bluetooth-behörighet"
            log("FEL: Bluetooth-behörighet saknas. Tillåt Cykelbrygga under Integritet och säkerhet > Bluetooth.")
        case .poweredOff:
            trainerState = "Bluetooth avstängt"
            log("FEL: Bluetooth är avstängt.")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let maker = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let company = maker.flatMap { $0.count >= 2 ? UInt16($0[0]) | UInt16($0[1]) << 8 : nil }
        let isTrainer = services.contains(ftmsService) || services.contains(cyclingPowerService)
        if services.contains(clickService) || company == zwiftCompanyID {
            guard clicks[peripheral.identifier] == nil, clicks.count < 4 else { return }
            let type = maker.flatMap { $0.count >= 3 ? $0[2] : nil }
            let click = Click(peripheral: peripheral, isV2: type == 0x0A || type == 0x0B || services.contains(clickService))
            clicks[peripheral.identifier] = click
            peripheral.delegate = self
            log("Ansluter till Zwift Click \(type == 0x0B ? "vänster" : type == 0x0A ? "höger" : "")")
            central.connect(peripheral)
            return
        }
        if controllersOnly { return }
        if isTrainer {
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Trainer"
            if seenTrainers[peripheral.identifier] == nil { log("Hittade \(name)\(services.contains(ftmsService) ? " (smart trainer)" : " (wattmätare)")") }
            seenTrainers[peripheral.identifier] = SeenTrainer(peripheral: peripheral, name: name,
                smart: services.contains(ftmsService), rssi: RSSI.intValue)
            pickTrainer()
        } else if services.contains(heartRateService), straps[peripheral.identifier] == nil, straps.count < 2 {
            straps[peripheral.identifier] = peripheral
            peripheral.delegate = self
            log("Ansluter till pulsband \(peripheral.name ?? "okänt")")
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let click = clicks[peripheral.identifier] {
            click.connectedAt = Date()
            peripheral.discoverServices([clickService, zwiftControllerService])
            return
        }
        peripheral.discoverServices([ftmsService, cyclingPowerService, heartRateService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Frånkopplad: \(peripheral.name ?? "okänd")")
        if let click = clicks[peripheral.identifier] {
            // Let go of anything it held down, then reconnect when it wakes up again.
            click.pressed = 0
            click.greeted = false
            updateButtons()
            central.connect(peripheral)
            return
        }
        forget(peripheral)
    }

    /// A connection that never came about (out of range, switched off): forget the device and look
    /// again, instead of waiting on "ansluter" forever.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Kunde inte ansluta: \(peripheral.name ?? "okänd")\(error.map { " (\($0.localizedDescription))" } ?? "")")
        if clicks[peripheral.identifier] != nil {
            clicks[peripheral.identifier] = nil
            updateButtons()
            scan()
            return
        }
        forget(peripheral)
    }

    private func forget(_ peripheral: CBPeripheral) {
        if peripheral == trainer {
            trainer = nil
            controlPoint = nil
            control = "ingen"
            trainerState = "söker"
            power = nil; cadence = nil; speedKmh = nil; relayHR = nil
            spindownSupported = nil
            if spindownActive {
                spindownActive = false
                link.send(["t": "spindown", "state": "fel", "reason": "trainern kopplades från"])
            }
        } else {
            straps[peripheral.identifier] = nil
        }
        scan()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if clicks[peripheral.identifier] != nil {
            for service in peripheral.services ?? [] {
                peripheral.discoverCharacteristics([clickAsync, clickSyncRx, clickSyncTx], for: service)
            }
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(
                [indoorBikeData, cyclingPowerMeasurement, heartRateMeasurement, ftmsControlPoint, ftmsStatus, ftmsFeature],
                for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let click = clicks[peripheral.identifier] {
            var syncRx: CBCharacteristic?
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == clickSyncRx { syncRx = characteristic }
                if characteristic.uuid == clickAsync || characteristic.uuid == clickSyncTx {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
            if let syncRx, !click.greeted {
                // The greeting the controllers wait for before they report buttons.
                let greeting = rideOn + (click.isV2 ? [0x02, 0x03] : [])
                let type: CBCharacteristicWriteType = syncRx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                peripheral.writeValue(Data(greeting), for: syncRx, type: type)
                click.greeted = true
                log("Zwift Click redo")
            }
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == ftmsControlPoint {
                controlPoint = characteristic
                peripheral.setNotifyValue(true, for: characteristic)   // indications carry the responses
            } else if characteristic.uuid == ftmsFeature {
                peripheral.readValue(for: characteristic)
            } else if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        if peripheral == trainer, service.uuid == ftmsService {
            trainerState = "klar"
            log("Trainer klar: \(peripheral.name ?? "okänd")")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        if let click = clicks[peripheral.identifier] {
            parseClick(data, from: click)
            return
        }
        switch characteristic.uuid {
        case indoorBikeData: parseIndoorBikeData(data)
        case cyclingPowerMeasurement where controlPoint == nil: parseCyclingPower(data)
        case heartRateMeasurement: parseHeartRate(data, from: peripheral)
        case ftmsControlPoint: parseControlResponse(data)
        case ftmsStatus: parseMachineStatus(data)
        case ftmsFeature: parseFeatures(data)
        default: break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("FEL vid skrivning till trainern: \(error.localizedDescription)") }
    }

    /// FTMS Indoor Bike Data (0x2AD2). Bit 0 = "More Data": when 0, instantaneous speed is present.
    private func parseIndoorBikeData(_ data: Data) {
        var r = ByteReader(data)
        guard let flags = r.u16() else { return }
        if flags & 0x0001 == 0, let v = r.u16() { speedKmh = Double(v) / 100 }
        if flags & 0x0002 != 0 { r.skip(2) }
        if flags & 0x0004 != 0, let v = r.u16() { cadence = Double(v) / 2 }
        if flags & 0x0008 != 0 { r.skip(2) }
        if flags & 0x0010 != 0 { r.skip(3) }
        if flags & 0x0020 != 0 { r.skip(2) }
        if flags & 0x0040 != 0, let v = r.s16() { power = Int(v) }
        sendData()
    }

    private func parseCyclingPower(_ data: Data) {
        var r = ByteReader(data)
        guard r.u16() != nil, let p = r.s16() else { return }
        power = Int(p)
        sendData()
    }

    private func parseHeartRate(_ data: Data, from peripheral: CBPeripheral) {
        var r = ByteReader(data)
        guard let flags = r.u8() else { return }
        guard let bpm = flags & 0x01 == 0 ? r.u8().map(Int.init) : r.u16().map(Int.init) else { return }
        if peripheral == trainer {
            relayHR = bpm
        } else {
            strapHR = (bpm, Date(), peripheral.name ?? "pulsband")
        }
    }

    /// A Click message: 0x23 = key pad (field 1, a 0 bit = pressed). FF 03 … is the unlock challenge
    /// a Click v2 sends when it has not been connected to the Zwift app lately.
    private func parseClick(_ data: Data, from click: Click) {
        let bytes = [UInt8](data)
        guard let type = bytes.first else { return }
        if type == 0xFF, bytes.count > 1, bytes[1] == 0x03 {
            if !click.lockedChallenge { log("Zwift Click ber om upplåsning (anslut den i Zwift-appen en gång per dygn)") }
            click.lockedChallenge = true
            return
        }
        guard type == 0x23, let map = protobufField1(bytes[1...]) else { return }
        if !click.reportedButtons { log("Zwift Click skickar knapptryck") }
        click.reportedButtons = true
        click.pressed = ~UInt32(truncatingIfNeeded: map) & 0x1FFFF
        updateButtons()
    }

    /// Send every button that went down or up since last time (the Clicks report each other's
    /// presses too, so their reports are combined).
    private func updateButtons() {
        let now = clicks.values.reduce(UInt32(0)) { $0 | $1.pressed }
        let changed = now ^ buttonsDown
        guard changed != 0 else { return }
        for (bit, name) in clickButtons where changed & bit != 0 {
            link.send(["t": "button", "id": name, "down": now & bit != 0])
        }
        buttonsDown = now
    }

    /// Control-point indication: 0x80, request opcode, result (0x01 = success).
    private func parseControlResponse(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 3, bytes[0] == 0x80 else { return }
        let (opcode, result) = (bytes[1], bytes[2])
        if opcode == 0x00 {
            if result == 0x01 {
                control = "given"
                log("Kontroll beviljad")
                if let trainer, let controlPoint {
                    trainer.writeValue(Data([0x07]), for: controlPoint, type: .withResponse)  // start/resume
                }
                flushPending()
            } else {
                control = "nekad"
                log("Kontroll nekad (kod \(result)). Är Zwift eller en cykeldator kopplad som styrd trainer?")
            }
        } else if opcode == 0x13 {
            if result == 0x01, bytes.count >= 7 {
                let low = Double(UInt16(bytes[3]) | UInt16(bytes[4]) << 8) / 100
                let high = Double(UInt16(bytes[5]) | UInt16(bytes[6]) << 8) / 100
                log(String(format: "Kalibrering: trampa upp till %.0f–%.0f km/h", low, high))
                link.send(["t": "spindown", "state": "trampa", "low": low, "high": high])
            } else if result == 0x01 {
                link.send(["t": "spindown", "state": "trampa"])
            } else {
                spindownActive = false
                log("Kalibreringen nekades (kod \(result))")
                link.send(["t": "spindown", "state": "fel", "reason": result == 0x02 ? "stöds inte" : "kod \(result)"])
                release(reason: "kalibreringen nekades")
            }
        } else if result != 0x01 {
            log(String(format: "Trainern svarade med fel %d på kommando 0x%02X", result, opcode))
        }
    }

    /// Fitness Machine Status (0x2ADA): 0x14 = spin down status (1 requested, 2 success, 3 error,
    /// 4 stop pedalling). Other status messages are ignored.
    private func parseMachineStatus(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 2, bytes[0] == 0x14 else { return }
        switch bytes[1] {
        case 0x01: link.send(["t": "spindown", "state": "trampa"])
        case 0x04: link.send(["t": "spindown", "state": "sluta"])
        case 0x02, 0x03:
            let ok = bytes[1] == 0x02
            log(ok ? "Kalibreringen lyckades" : "Kalibreringen misslyckades")
            spindownActive = false
            link.send(["t": "spindown", "state": ok ? "klar" : "fel", "reason": ok ? "" : "trainern rapporterade fel"])
            release(reason: "kalibreringen är klar")
        default: break
        }
    }

    /// Fitness Machine Feature (0x2ACC): two 32-bit fields; bit 15 of the second (target settings)
    /// says the trainer can spin down on command.
    private func parseFeatures(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return }
        let targets = UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24
        spindownSupported = targets & (1 << 15) != 0
        log("Trainern kan \(spindownSupported! ? "" : "inte ")kalibreras via FTMS")
    }

    private func sendData() {
        let hr: Int? = {
            if let strapHR, Date().timeIntervalSince(strapHR.at) < 3 { return strapHR.bpm }
            return relayHR
        }()
        link.send([
            "t": "data",
            "power": power ?? NSNull(),
            "cadence": cadence ?? NSNull(),
            "speed": speedKmh ?? NSNull(),
            "hr": hr ?? NSNull(),
        ])
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let bridge = Bridge()
bridge.start()
app.run()
