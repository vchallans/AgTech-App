import XCTest
@testable import BioReactor

private final class MockBluetoothManager: GroBotBluetoothManaging {
    weak var delegate: GroBotBluetoothManagerDelegate?
    private(set) var startScanCallCount = 0

    func startScan() {
        startScanCallCount += 1
    }

    func emitStatus(_ status: GroBotBluetoothStatus) {
        delegate?.bluetoothManager(self, didChangeStatus: status)
    }

    func emitCO2(_ ppm: Double) {
        delegate?.bluetoothManager(self, didReceiveCO2: ppm)
    }
}

final class PhotobioreactorViewModelBluetoothTests: XCTestCase {
    func test_scanForDevice_startsBluetoothScan() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        viewModel.scanForDevice()

        XCTAssertEqual(bluetoothManager.startScanCallCount, 1)
    }

    func test_connectedStatus_updatesDiscoveryState() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        bluetoothManager.emitStatus(.scanning)
        bluetoothManager.emitStatus(.connecting(deviceName: "BioReactor-ESP32"))
        bluetoothManager.emitStatus(.connected(deviceName: "BioReactor-ESP32"))

        XCTAssertFalse(viewModel.isScanningForDevice)
        XCTAssertTrue(viewModel.isConnected)
        XCTAssertEqual(viewModel.discoveredDeviceName, "BioReactor-ESP32")
        XCTAssertEqual(viewModel.bluetoothStatusMessage, "Connected to BioReactor-ESP32")
    }

    func test_receivedCO2_updatesCurrentReading() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        bluetoothManager.emitCO2(583)

        XCTAssertEqual(viewModel.currentReading.co2ppm, 583, accuracy: 0.001)
    }
}
