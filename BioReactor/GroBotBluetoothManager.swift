import CoreBluetooth
import Foundation

enum GroBotBluetoothStatus: Equatable {
    case idle
    case scanning
    case connecting(deviceName: String)
    case connected(deviceName: String)
    case failed(message: String)
}

protocol GroBotBluetoothManagerDelegate: AnyObject {
    func bluetoothManager(_ manager: GroBotBluetoothManaging, didChangeStatus status: GroBotBluetoothStatus)
    func bluetoothManager(_ manager: GroBotBluetoothManaging, didReceiveCO2 ppm: Double)
}

protocol GroBotBluetoothManaging: AnyObject {
    var delegate: GroBotBluetoothManagerDelegate? { get set }
    func startScan()
}

final class GroBotBluetoothManager: NSObject, GroBotBluetoothManaging {
    weak var delegate: GroBotBluetoothManagerDelegate?

    private static let serviceUUID = CBUUID(string: "B7E20001-4A12-4F5A-A8D4-9C3B7E110001")
    private static let co2CharacteristicUUID = CBUUID(string: "B7E20002-4A12-4F5A-A8D4-9C3B7E110001")
    private static let scanTimeoutSeconds: TimeInterval = 8.0
    private static let expectedNamePrefix = "BioReactor"

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var scanTimeoutWorkItem: DispatchWorkItem?
    private var pendingScan = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        pendingScan = true
        print("BLE scan requested. Current central state: \(centralManager.state.rawValue)")

        guard centralManager.state == .poweredOn else {
            emitStatus(unavailableStatus(for: centralManager.state))
            return
        }

        beginScan()
    }

    private func beginScan() {
        pendingScan = false
        cancelScanTimeout()
        print("BLE scan starting for service \(Self.serviceUUID.uuidString)")

        if let connectedPeripheral {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
            self.connectedPeripheral = nil
        }

        emitStatus(.scanning)
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.centralManager.stopScan()
            self.emitStatus(.failed(message: "No Gro-Bot device found nearby."))
        }

        scanTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanTimeoutSeconds, execute: timeoutWorkItem)
    }

    private func connect(to peripheral: CBPeripheral, advertisedName: String) {
        cancelScanTimeout()
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        print("BLE discovered \(advertisedName); attempting connection")
        emitStatus(.connecting(deviceName: advertisedName))
        centralManager.connect(peripheral)
    }

    private func emitStatus(_ status: GroBotBluetoothStatus) {
        print("BLE status -> \(status)")
        delegate?.bluetoothManager(self, didChangeStatus: status)
    }

    private func cancelScanTimeout() {
        scanTimeoutWorkItem?.cancel()
        scanTimeoutWorkItem = nil
    }

    private func unavailableStatus(for state: CBManagerState) -> GroBotBluetoothStatus {
        switch state {
        case .poweredOff:
            return .failed(message: "Bluetooth is turned off on this phone.")
        case .unauthorized:
            return .failed(message: "Bluetooth permission has not been granted.")
        case .unsupported:
            return .failed(message: "Bluetooth LE is not supported on this device.")
        case .resetting:
            return .failed(message: "Bluetooth is resetting. Try again in a moment.")
        case .unknown:
            return .failed(message: "Bluetooth is still initializing.")
        case .poweredOn:
            return .idle
        @unknown default:
            return .failed(message: "Bluetooth is unavailable right now.")
        }
    }

    private func peripheralName(for peripheral: CBPeripheral, advertisementData: [String: Any]) -> String {
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
            return localName
        }

        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            return peripheralName
        }

        return "Gro-Bot"
    }

    private func isGroBotPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        let deviceName = peripheralName(for: peripheral, advertisementData: advertisementData)
        if deviceName.hasPrefix(Self.expectedNamePrefix) {
            return true
        }

        if let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            return advertisedServices.contains(Self.serviceUUID)
        }

        return false
    }

    private func parseCO2Value(from data: Data) -> Double? {
        guard data.count >= 4 else { return nil }

        var ppm = UInt32(0)
        for (index, byte) in data.prefix(4).enumerated() {
            ppm |= UInt32(byte) << (UInt32(index) * 8)
        }

        return Double(ppm)
    }
}

extension GroBotBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("BLE central state changed: \(central.state.rawValue)")
        if central.state == .poweredOn {
            if pendingScan {
                beginScan()
            } else {
                emitStatus(.idle)
            }
            return
        }

        emitStatus(unavailableStatus(for: central.state))
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let deviceName = peripheralName(for: peripheral, advertisementData: advertisementData)
        let advertisedServices = ((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? [])
            .map(\.uuidString)
        print("BLE didDiscover peripheral=\(peripheral.identifier.uuidString) name=\(deviceName) rssi=\(RSSI) services=\(advertisedServices)")

        guard isGroBotPeripheral(peripheral, advertisementData: advertisementData) else {
            return
        }
        connect(to: peripheral, advertisedName: deviceName)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let deviceName = peripheral.name ?? "Gro-Bot"
        print("BLE didConnect \(deviceName)")
        emitStatus(.connected(deviceName: deviceName))
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectedPeripheral = nil
        let message = error?.localizedDescription ?? "The device connection failed."
        print("BLE didFailToConnect: \(message)")
        emitStatus(.failed(message: "Failed to connect: \(message)"))
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectedPeripheral = nil
        print("BLE didDisconnect peripheral=\(peripheral.identifier.uuidString) error=\(String(describing: error))")

        if let error {
            emitStatus(.failed(message: "Connection lost: \(error.localizedDescription)"))
        } else {
            emitStatus(.idle)
        }
    }
}

extension GroBotBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("BLE didDiscoverServices error: \(error!.localizedDescription)")
            emitStatus(.failed(message: "Could not discover Gro-Bot services."))
            return
        }

        print("BLE services discovered: \(peripheral.services?.map { $0.uuid.uuidString } ?? [])")

        peripheral.services?
            .filter { $0.uuid == Self.serviceUUID }
            .forEach { peripheral.discoverCharacteristics([Self.co2CharacteristicUUID], for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            print("BLE didDiscoverCharacteristics error: \(error!.localizedDescription)")
            emitStatus(.failed(message: "Could not discover Gro-Bot characteristics."))
            return
        }

        print("BLE characteristics discovered for service \(service.uuid.uuidString): \(service.characteristics?.map { $0.uuid.uuidString } ?? [])")

        service.characteristics?
            .filter { $0.uuid == Self.co2CharacteristicUUID }
            .forEach {
                peripheral.setNotifyValue(true, for: $0)
                peripheral.readValue(for: $0)
            }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            print("BLE didUpdateValue error: \(error!.localizedDescription)")
            emitStatus(.failed(message: "Could not read the Gro-Bot CO2 characteristic."))
            return
        }

        guard characteristic.uuid == Self.co2CharacteristicUUID,
              let value = characteristic.value,
              let ppm = parseCO2Value(from: value) else {
            print("BLE didUpdateValue ignored for characteristic \(characteristic.uuid.uuidString)")
            return
        }

        print("BLE CO2 update -> \(ppm) ppm")
        delegate?.bluetoothManager(self, didReceiveCO2: ppm)
    }
}
