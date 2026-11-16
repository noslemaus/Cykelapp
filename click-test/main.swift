// ClickTest — reads button presses from Zwift Click controllers (v1 and the v2 pair) and logs them.
// It first only listens. If no buttons arrive it sends the standard "RideOn" greeting that Zwift's
// controllers wait for before they report buttons. Nothing else is ever written to the Clicks:
// no settings, no firmware, no pairing changes.
//
// Protocol notes (from the open-source BikeControl app and community reverse engineering):
//   service  00000001-19CA-4651-86E5-FA29DCDD09D1 (or FC82 on Click v2 / Ride)
//   async    00000002-…  notify     button and battery messages
//   sync rx  00000003-…  write      the greeting goes here
//   sync tx  00000004-…  indicate   the controller's answer to the greeting
//   greeting "RideOn" (52 69 64 65 4F 6E), on Click v2 followed by 02 03
//   message  first byte = type: 0x23 Ride/Click v2 buttons, 0x37 Click v1 buttons, 0x19 battery,
//            0x15 empty; the rest is a protobuf. Pressed buttons read as 0 bits.
import AppKit
import CoreBluetooth
import Foundation

let zwiftService = CBUUID(string: "00000001-19CA-4651-86E5-FA29DCDD09D1")
let rideService = CBUUID(string: "FC82")
let asyncChar = CBUUID(string: "00000002-19CA-4651-86E5-FA29DCDD09D1")
let syncRxChar = CBUUID(string: "00000003-19CA-4651-86E5-FA29DCDD09D1")
let syncTxChar = CBUUID(string: "00000004-19CA-4651-86E5-FA29DCDD09D1")
let zwiftCompanyID: UInt16 = 0x094A
let rideOn: [UInt8] = [0x52, 0x69, 0x64, 0x65, 0x4F, 0x6E]

/// Button bits of the Ride / Click v2 key pad (a 0 bit means pressed).
let rideButtons: [(UInt32, String)] = [
    (0x00001, "vänster"), (0x00002, "upp"), (0x00004, "höger"), (0x00008, "ner"),
    (0x00010, "A"), (0x00020, "B"), (0x00040, "Y"), (0x00080, "Z"),
    (0x00100, "växla upp V"), (0x00200, "växla ner V"), (0x00400, "power-up V"), (0x00800, "på/av V"),
    (0x01000, "växla upp H"), (0x02000, "växla ner H"), (0x04000, "power-up H"), (0x08000, "på/av H"),
]

let args = CommandLine.arguments
let logPath = args.count > 1 ? args[1] : NSTemporaryDirectory() + "clicktest.log"
let durationSeconds = args.count > 2 ? (Double(args[2]) ?? 240) : 240
let listenFirstSeconds = 10.0

FileManager.default.createFile(atPath: logPath, contents: nil)
let logHandle = FileHandle(forWritingAtPath: logPath)!
let startTime = Date()

func log(_ message: String) {
    let t = String(format: "%6.1fs", Date().timeIntervalSince(startTime))
    logHandle.write("[\(t)] \(message)\n".data(using: .utf8)!)
}

func hex(_ data: Data) -> String { data.map { String(format: "%02X", $0) }.joined(separator: " ") }

/// Protobuf fields of a message: field number → varint value (other wire types are skipped).
func protobufVarints(_ bytes: [UInt8]) -> [(Int, UInt64)] {
    var out: [(Int, UInt64)] = []
    var i = 0
    func varint() -> UInt64? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while i < bytes.count {
            let b = bytes[i]
            i += 1
            value |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { return value }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }
    while i < bytes.count {
        guard let key = varint() else { break }
        let field = Int(key >> 3)
        switch key & 7 {
        case 0:
            guard let v = varint() else { return out }
            out.append((field, v))
        case 1: i += 8
        case 2:
            guard let len = varint() else { return out }
            i += Int(len)
        case 5: i += 4
        default: return out
        }
    }
    return out
}

final class Controller {
    let peripheral: CBPeripheral
    let label: String
    let isV2: Bool
    var syncRx: CBCharacteristic?
    var greeted = false
    var buttonMessages = 0
    var lastValue = Data()
    var repeats = 0

    init(peripheral: CBPeripheral, label: String, isV2: Bool) {
        self.peripheral = peripheral
        self.label = label
        self.isV2 = isV2
    }
}

final class Tester: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var controllers: [UUID: Controller] = [:]
    private var seen = Set<UUID>()

    func start() {
        log("Startar Click-test i \(Int(durationSeconds)) s. Loggfil: \(logPath)")
        log("Väck dina Click genom att trycka på en knapp. Zwift ska vara stängt överallt.")
        central = CBCentralManager(delegate: self, queue: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds) { self.finish() }
    }

    func finish() {
        log("--- Sammanfattning ---")
        if controllers.isEmpty {
            log("Ingen Zwift Click hittades.")
        }
        for c in controllers.values {
            log("\(c.label): \(c.buttonMessages) knappmeddelanden, hälsning skickad: \(c.greeted ? "ja" : "nej")")
        }
        for c in controllers.values { central.cancelPeripheralConnection(c.peripheral) }
        log("Klart.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exit(0) }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("Bluetooth-läge: \(central.state.rawValue) (5 = på)")
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            log("Söker …")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        let maker = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let company = maker.flatMap { $0.count >= 2 ? UInt16($0[0]) | UInt16($0[1]) << 8 : nil }
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let isZwift = company == zwiftCompanyID || name.localizedCaseInsensitiveContains("zwift")
            || services.contains(rideService) || services.contains(zwiftService)
        guard isZwift, !seen.contains(peripheral.identifier) else { return }
        seen.insert(peripheral.identifier)
        let typeByte = maker.flatMap { $0.count >= 3 ? $0[2] : nil }
        let kind: String
        switch typeByte {
        case 0x09: kind = "Click v1"
        case 0x0A: kind = "Click v2 höger"
        case 0x0B: kind = "Click v2 vänster"
        case 0x07: kind = "Ride höger"
        case 0x08: kind = "Ride vänster"
        default: kind = "okänd typ \(typeByte.map { String(format: "0x%02X", $0) } ?? "-")"
        }
        let label = "\(name.isEmpty ? "Zwift" : name) [\(kind)]"
        log("Hittade \(label), RSSI \(RSSI), tillverkardata \(maker.map(hex) ?? "-"), tjänster \(services)")
        let c = Controller(peripheral: peripheral, label: label, isV2: typeByte == 0x0A || typeByte == 0x0B || services.contains(rideService))
        controllers[peripheral.identifier] = c
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Ansluten: \(label(peripheral))")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Kunde inte ansluta \(label(peripheral)): \(error?.localizedDescription ?? "-")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Frånkopplad: \(label(peripheral)) \(error?.localizedDescription ?? "")")
        if let c = controllers[peripheral.identifier] {
            c.greeted = false
            central.connect(peripheral, options: nil)      // try again (the Click may just have slept)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] {
            log("  \(label(peripheral)) tjänst \(s.uuid)")
            peripheral.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let c = controllers[peripheral.identifier] else { return }
        for ch in service.characteristics ?? [] {
            var props: [String] = []
            if ch.properties.contains(.read) { props.append("läs") }
            if ch.properties.contains(.write) { props.append("skriv") }
            if ch.properties.contains(.writeWithoutResponse) { props.append("skriv-utan-svar") }
            if ch.properties.contains(.notify) { props.append("notify") }
            if ch.properties.contains(.indicate) { props.append("indicate") }
            log("    egenskap \(ch.uuid) (\(props.joined(separator: ", ")))")
            if ch.uuid == syncRxChar { c.syncRx = ch }
            if ch.properties.contains(.notify) || ch.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: ch)
            }
            if ch.uuid == CBUUID(string: "2A19") { peripheral.readValue(for: ch) }      // battery level
        }
        if service.uuid == zwiftService || service.uuid == rideService {
            log("  Lyssnar på \(c.label) i \(Int(listenFirstSeconds)) s innan hälsningen skickas …")
            DispatchQueue.main.asyncAfter(deadline: .now() + listenFirstSeconds) { self.greetIfQuiet(c) }
        }
    }

    /// Send "RideOn" (plus 02 03 on a Click v2) if the Click has not reported any buttons yet.
    private func greetIfQuiet(_ c: Controller) {
        guard !c.greeted, c.buttonMessages == 0, let rx = c.syncRx else { return }
        var bytes = rideOn
        if c.isV2 { bytes += [0x02, 0x03] }
        let type: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        c.peripheral.writeValue(Data(bytes), for: rx, type: type)
        c.greeted = true
        log("  Skickade hälsningen \(hex(Data(bytes))) till \(c.label). Tryck på knapparna nu.")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("    kunde inte prenumerera på \(characteristic.uuid): \(error.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let c = controllers[peripheral.identifier], let data = characteristic.value else { return }
        if characteristic.uuid == CBUUID(string: "2A19"), let level = data.first {
            log("\(c.label): batteri \(level) %")
            return
        }
        // Collapse identical repeats (the controllers resend the same state).
        if data == c.lastValue {
            c.repeats += 1
            return
        }
        if c.repeats > 0 { log("\(c.label): (samma meddelande ×\(c.repeats + 1))") }
        c.lastValue = data
        c.repeats = 0
        let bytes = [UInt8](data)
        let where_ = characteristic.uuid == asyncChar ? "async" : characteristic.uuid == syncTxChar ? "sync-tx" : "\(characteristic.uuid)"
        var text = "\(c.label) \(where_): \(hex(data))"
        if let type = bytes.first {
            let fields = protobufVarints(Array(bytes.dropFirst()))
            switch type {
            case 0x23:
                c.buttonMessages += 1
                if let map = fields.first(where: { $0.0 == 1 })?.1 {
                    let pressed = rideButtons.filter { UInt64($0.0) & map == 0 }.map { $0.1 }
                    text += "  → knappar: \(pressed.isEmpty ? "inga" : pressed.joined(separator: ", ")) (karta 0x\(String(map, radix: 16)))"
                }
                if fields.count > 1 { text += " fält \(fields.map { "\($0.0)=\($0.1)" }.joined(separator: " "))" }
            case 0x37:
                c.buttonMessages += 1
                let plus = fields.first(where: { $0.0 == 1 })?.1
                let minus = fields.first(where: { $0.0 == 2 })?.1
                text += "  → plus \(plus == 0 ? "NERE" : "uppe"), minus \(minus == 0 ? "NERE" : "uppe")"
            case 0x19:
                text += "  → batteri \(fields.map { "\($0.0)=\($0.1)" }.joined(separator: " "))"
            case 0x15:
                text += "  → tomt"
            default:
                if bytes.starts(with: rideOn) { text += "  → svar på hälsningen" }
                else if !fields.isEmpty { text += "  → fält \(fields.map { "\($0.0)=\($0.1)" }.joined(separator: " "))" }
            }
        }
        log(text)
    }

    private func label(_ p: CBPeripheral) -> String { controllers[p.identifier]?.label ?? (p.name ?? "?") }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let tester = Tester()
tester.start()
app.run()
