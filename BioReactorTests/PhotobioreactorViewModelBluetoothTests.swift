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

    func emitUpdate(_ update: GroBotSensorUpdate) {
        delegate?.bluetoothManager(self, didReceiveSensorUpdate: update)
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

    func test_receivedSensorUpdate_mergesMultipleLiveFieldsIntoCurrentReading() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        bluetoothManager.emitUpdate(
            GroBotSensorUpdate(
                co2ppm: 583,
                temperatureC: 26.4,
                humidityPercent: 61.2,
                airflowSlm: 1.75
            )
        )

        XCTAssertEqual(viewModel.currentReading.co2ppm, 583, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.temperatureC, 26.4, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.humidityPercent, 61.2, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.airflowSlm, 1.75, accuracy: 0.001)
    }

    func test_receivedPartialSensorUpdate_keepsUnchangedFields() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )
        let initialReading = viewModel.currentReading

        bluetoothManager.emitUpdate(
            GroBotSensorUpdate(
                temperatureC: 27.0,
                airflowSlm: 0.92
            )
        )

        XCTAssertEqual(viewModel.currentReading.co2ppm, initialReading.co2ppm, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.o2ppm, initialReading.o2ppm, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.temperatureC, 27.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.humidityPercent, initialReading.humidityPercent, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.airflowSlm, 0.92, accuracy: 0.001)
    }
}
