// BLETest — read-only Bluetooth test: finds an FTMS trainer and heart-rate straps,
// subscribes to Indoor Bike Data / Cycling Power / Heart Rate and logs values once per second.
// Never writes to the trainer's control point, so resistance is untouched.
import AppKit
import CoreBluetooth
import Foundation

let ftmsService = CBUUID(string: "1826")
let cyclingPowerService = CBUUID(string: "1818")
let heartRateService = CBUUID(string: "180D")
let indoorBikeData = CBUUID(string: "2AD2")
let cyclingPowerMeasurement = CBUUID(string: "2A63")
let heartRateMeasurement = CBUUID(string: "2A37")
let fitnessMachineFeature = CBUUID(string: "2ACC")
let supportedResistanceRange = CBUUID(string: "2AD6")
let supportedPowerRange = CBUUID(string: "2AD8")
let ftmsControlPoint = CBUUID(string: "2AD9")
/// Read-only characteristics that describe what the trainer can be told to do (ERG, SIM, resistance).
let capabilityCharacteristics = [fitnessMachineFeature, supportedResistanceRange, supportedPowerRange, ftmsControlPoint]

let args = CommandLine.arguments
let logPath = args.count > 1 ? args[1] : NSTemporaryDirectory() + "bletest.log"
let durationSeconds = args.count > 2 ? (Double(args[2]) ?? 120) : 120

FileManager.default.createFile(atPath: logPath, contents: nil)
let logHandle = FileHandle(forWritingAtPath: logPath)!
let startTime = Date()

func log(_ message: String) {
    let t = String(format: "%5.1fs", Date().timeIntervalSince(startTime))
    logHandle.write("[\(t)] \(message)\n".data(using: .utf8)!)
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
    mutating func u24() -> UInt32? {
        guard remaining >= 3 else { return nil }
        defer { offset += 3 }
        return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16
    }
    mutating func skip(_ n: Int) { offset = min(bytes.count, offset + n) }
}

/// Latest values per device, printed once per second.
struct TrainerReading {
    var speedKmh: Double?
    var cadenceRpm: Double?
    var powerW: Int?
    var heartRate: Int?
    var distanceM: UInt32?
    var packets = 0
}

final class Tester: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var trainer: CBPeripheral?
    private var hrStraps: [UUID: CBPeripheral] = [:]
    private var discovered = Set<UUID>()
    private var reading = TrainerReading()
    private var heartRates: [UUID: (name: String, bpm: Int, packets: Int)] = [:]
    private var cpsPower: Int?

    func start() {
        log("Startar Bluetooth-test i \(Int(durationSeconds)) s. Loggfil: \(logPath)")
        central = CBCentralManager(delegate: self, queue: nil)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.printStatus() }
        Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { [weak self] _ in self?.finish() }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("Bluetooth på. Söker efter trainer (FTMS/Cycling Power) och pulsband...")
            central.scanForPeripherals(withServices: [ftmsService, cyclingPowerService, heartRateService],
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        case .unauthorized:
            log("FEL: Bluetooth-behörighet nekad. Tillåt BLETest under Systeminställningar > Integritet och säkerhet > Bluetooth.")
            finish()
        case .poweredOff:
            log("FEL: Bluetooth är avstängt.")
            finish()
        case .unsupported:
            log("FEL: Bluetooth LE stöds inte.")
            finish()
        default:
            log("Bluetooth-läge: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "okänd"
        if discovered.insert(peripheral.identifier).inserted {
            log("Hittade \(name) (RSSI \(RSSI)) tjänster: \(services.map { $0.uuidString }.joined(separator: ","))")
        }
        let isTrainer = services.contains(ftmsService) || services.contains(cyclingPowerService)
        if isTrainer && trainer == nil {
            trainer = peripheral
            peripheral.delegate = self
            log("Ansluter till trainer \(name)...")
            central.connect(peripheral)
        } else if services.contains(heartRateService) && hrStraps[peripheral.identifier] == nil && hrStraps.count < 3 {
            hrStraps[peripheral.identifier] = peripheral
            peripheral.delegate = self
            log("Ansluter till pulsband \(name)...")
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Ansluten: \(peripheral.name ?? "okänd")")
        peripheral.discoverServices([ftmsService, cyclingPowerService, heartRateService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("FEL: kunde inte ansluta till \(peripheral.name ?? "okänd"): \(error?.localizedDescription ?? "okänt fel")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Frånkopplad: \(peripheral.name ?? "okänd") \(error?.localizedDescription ?? "")")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            log("  \(peripheral.name ?? "?") har tjänst \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics([indoorBikeData, cyclingPowerMeasurement, heartRateMeasurement] + capabilityCharacteristics, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] where capabilityCharacteristics.contains(characteristic.uuid) {
            if characteristic.uuid == ftmsControlPoint {
                let p = characteristic.properties
                log("  Kontrollpunkt 2AD9 finns: skriv=\(p.contains(.write)), indikera=\(p.contains(.indicate)) (testet skriver aldrig dit)")
            } else if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
        for characteristic in service.characteristics ?? [] where characteristic.properties.contains(.notify)
            && !capabilityCharacteristics.contains(characteristic.uuid) {
            log("  Prenumererar på \(characteristic.uuid.uuidString) från \(peripheral.name ?? "?")")
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        switch characteristic.uuid {
        case indoorBikeData: parseIndoorBikeData(data)
        case cyclingPowerMeasurement: parseCyclingPower(data)
        case heartRateMeasurement: parseHeartRate(data, from: peripheral)
        case fitnessMachineFeature: parseFeatures(data)
        case supportedPowerRange, supportedResistanceRange: parseRange(data, for: characteristic.uuid)
        default: break
        }
    }

    /// FTMS Indoor Bike Data (0x2AD2). Bit 0 = "More Data": when 0, instantaneous speed is present.
    private func parseIndoorBikeData(_ data: Data) {
        var r = ByteReader(data)
        guard let flags = r.u16() else { return }
        reading.packets += 1
        if flags & 0x0001 == 0, let v = r.u16() { reading.speedKmh = Double(v) / 100 }
        if flags & 0x0002 != 0 { r.skip(2) }                                   // average speed
        if flags & 0x0004 != 0, let v = r.u16() { reading.cadenceRpm = Double(v) / 2 }
        if flags & 0x0008 != 0 { r.skip(2) }                                   // average cadence
        if flags & 0x0010 != 0, let v = r.u24() { reading.distanceM = v }
        if flags & 0x0020 != 0 { r.skip(2) }                                   // resistance level
        if flags & 0x0040 != 0, let v = r.s16() { reading.powerW = Int(v) }
        if flags & 0x0080 != 0 { r.skip(2) }                                   // average power
        if flags & 0x0100 != 0 { r.skip(5) }                                   // expended energy
        if flags & 0x0200 != 0, let v = r.u8() { reading.heartRate = Int(v) }
    }

    /// Fitness Machine Feature (0x2ACC): uint32 machine features, uint32 target-setting features.
    private func parseFeatures(_ data: Data) {
        var r = ByteReader(data)
        guard let m0 = r.u16(), let m1 = r.u16(), let t0 = r.u16(), let t1 = r.u16() else { return }
        let machine = UInt32(m0) | UInt32(m1) << 16
        let target = UInt32(t0) | UInt32(t1) << 16
        let machineNames: [(Int, String)] = [(1, "kadens"), (2, "distans"), (7, "motståndsnivå"), (10, "puls"), (12, "tid"), (14, "watt")]
        let targetNames: [(Int, String)] = [(2, "motstånd"), (3, "målwatt (ERG)"), (13, "simulering (SIM)"), (14, "hjulomkrets"), (15, "spin down"), (16, "målkadens")]
        func names(_ bits: UInt32, _ table: [(Int, String)]) -> String {
            table.filter { bits & (1 << UInt32($0.0)) != 0 }.map { $0.1 }.joined(separator: ", ")
        }
        log(String(format: "  Funktioner 2ACC: maskin=0x%08X mål=0x%08X", machine, target))
        log("  Mäter: \(names(machine, machineNames))")
        log("  Kan styras med: \(names(target, targetNames))")
    }

    /// Supported Power Range (0x2AD8) in watts, Supported Resistance Level Range (0x2AD6) in 0.1 units.
    private func parseRange(_ data: Data, for uuid: CBUUID) {
        var r = ByteReader(data)
        guard let lo = r.s16(), let hi = r.s16(), let step = r.u16() else { return }
        if uuid == supportedPowerRange {
            log("  Wattintervall 2AD8: \(lo)–\(hi) W i steg om \(step) W")
        } else {
            log("  Motståndsintervall 2AD6: \(Double(lo) / 10)–\(Double(hi) / 10) i steg om \(Double(step) / 10)")
        }
    }

    /// Cycling Power Measurement (0x2A63): flags (2 bytes) then instantaneous power (sint16).
    private func parseCyclingPower(_ data: Data) {
        var r = ByteReader(data)
        guard r.u16() != nil, let p = r.s16() else { return }
        cpsPower = Int(p)
    }

    /// Heart Rate Measurement (0x2A37): bit 0 of flags selects uint8 or uint16 value.
    private func parseHeartRate(_ data: Data, from peripheral: CBPeripheral) {
        var r = ByteReader(data)
        guard let flags = r.u8() else { return }
        let bpm = flags & 0x01 == 0 ? r.u8().map(Int.init) : r.u16().map(Int.init)
        guard let bpm else { return }
        let previous = heartRates[peripheral.identifier]?.packets ?? 0
        heartRates[peripheral.identifier] = (peripheral.name ?? "pulsband", bpm, previous + 1)
    }

    private func printStatus() {
        var parts: [String] = []
        if trainer != nil {
            let speed = reading.speedKmh.map { String(format: "%.1f km/h", $0) } ?? "– km/h"
            let cadence = reading.cadenceRpm.map { String(format: "%.0f rpm", $0) } ?? "– rpm"
            let power = reading.powerW.map { "\($0) W" } ?? (cpsPower.map { "\($0) W (CPS)" } ?? "– W")
            parts.append("\(trainer?.name ?? "trainer"): \(power), \(cadence), \(speed)")
        }
        for (_, hr) in heartRates { parts.append("\(hr.name): \(hr.bpm) bpm") }
        if !parts.isEmpty { log(parts.joined(separator: " | ")) }
    }

    private func finish() {
        log("SAMMANFATTNING: trainerpaket=\(reading.packets), senaste watt=\(reading.powerW.map(String.init) ?? "-"), "
            + "kadens=\(reading.cadenceRpm.map { String(format: "%.0f", $0) } ?? "-"), "
            + "fart=\(reading.speedKmh.map { String(format: "%.1f", $0) } ?? "-"), "
            + "puls=\(heartRates.values.map { "\($0.name) \($0.bpm) bpm (\($0.packets) paket)" }.joined(separator: "; "))")
        central?.stopScan()
        if let trainer { central.cancelPeripheralConnection(trainer) }
        for strap in hrStraps.values { central.cancelPeripheralConnection(strap) }
        log("KLART")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exit(0) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let tester = Tester()
tester.start()
app.run()
