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

    func test_receivedSensorUpdate_mergesInputAndOutputFieldsIntoCurrentReading() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        bluetoothManager.emitUpdate(
            GroBotSensorUpdate(
                inputCo2ppm: 583,
                inputTemperatureC: 26.4,
                inputHumidityPercent: 61.2,
                outputCo2ppm: 742,
                outputTemperatureC: 25.1,
                outputHumidityPercent: 58.4,
                outputO2Percent: 20.9,
                airflowSlm: 1.75
            )
        )

        XCTAssertEqual(viewModel.currentReading.inputCo2ppm, 583, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.inputTemperatureC, 26.4, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.inputHumidityPercent, 61.2, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputCo2ppm, 742, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputTemperatureC, 25.1, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputHumidityPercent, 58.4, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputO2Percent, 20.9, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.airflowSlm, 1.75, accuracy: 0.001)
    }

    func test_receivedPartialSensorUpdate_keepsUnchangedFieldsAcrossSections() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )
        let initialReading = viewModel.currentReading

        bluetoothManager.emitUpdate(
            GroBotSensorUpdate(
                outputCo2ppm: 801,
                outputO2Percent: 19.4
            )
        )

        XCTAssertEqual(viewModel.currentReading.inputCo2ppm, initialReading.inputCo2ppm, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.inputTemperatureC, initialReading.inputTemperatureC, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.inputHumidityPercent, initialReading.inputHumidityPercent, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputCo2ppm, 801, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputTemperatureC, initialReading.outputTemperatureC, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputHumidityPercent, initialReading.outputHumidityPercent, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentReading.outputO2Percent, 19.4, accuracy: 0.001)
        XCTAssertTrue(viewModel.currentReading.airflowSlm.isNaN)
    }
}
