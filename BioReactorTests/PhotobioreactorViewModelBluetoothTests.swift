import XCTest
@testable import BioReactor

private final class MockBluetoothManager: GroBotBluetoothManaging {
    weak var delegate: GroBotBluetoothManagerDelegate?
    private(set) var startScanCallCount = 0
    private(set) var lastPumpOnValue: Bool?
    private(set) var lastPumpPercent: UInt8?

    func startScan() {
        startScanCallCount += 1
    }

    func setPump(on: Bool) {
        lastPumpOnValue = on
    }

    func setPump(percent: UInt8) {
        lastPumpPercent = percent
    }

    func emitStatus(_ status: GroBotBluetoothStatus) {
        delegate?.bluetoothManager(self, didChangeStatus: status)
    }

    func emitUpdate(_ update: GroBotSensorUpdate) {
        delegate?.bluetoothManager(self, didReceiveSensorUpdate: update)
    }
}

final class PhotobioreactorViewModelBluetoothTests: XCTestCase {
    func test_rollingHistoryWindow_keepsOnlyLastHourRelativeToNewestReading() {
        let baseTime = Date(timeIntervalSince1970: 1_776_900_000)
        let readings = [
            makeReading(timestamp: baseTime.addingTimeInterval(-4_000), inputCo2ppm: 610, outputCo2ppm: 500, outputO2Percent: 20.3),
            makeReading(timestamp: baseTime.addingTimeInterval(-3_500), inputCo2ppm: 625, outputCo2ppm: 510, outputO2Percent: 20.4),
            makeReading(timestamp: baseTime.addingTimeInterval(-3_000), inputCo2ppm: 640, outputCo2ppm: 520, outputO2Percent: 20.5),
            makeReading(timestamp: baseTime.addingTimeInterval(-1_200), inputCo2ppm: 660, outputCo2ppm: 535, outputO2Percent: 20.7),
            makeReading(timestamp: baseTime, inputCo2ppm: 680, outputCo2ppm: 545, outputO2Percent: 20.9)
        ]

        let window = PhotobioreactorViewModel.rollingHistoryWindow(from: readings)

        XCTAssertEqual(window.map(\.timestamp), [
            baseTime.addingTimeInterval(-3_500),
            baseTime.addingTimeInterval(-3_000),
            baseTime.addingTimeInterval(-1_200),
            baseTime
        ])
        XCTAssertEqual(window.map(\.inputCo2ppm), [625.0, 640.0, 660.0, 680.0])
    }

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

    func test_firstLiveSensorUpdate_replacesSeedHistoryReading() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        XCTAssertEqual(viewModel.history.count, 1)
        XCTAssertEqual(viewModel.history[0].outputO2Percent, 20.9, accuracy: 0.001)

        bluetoothManager.emitUpdate(
            GroBotSensorUpdate(
                inputCo2ppm: 702,
                outputCo2ppm: 618,
                outputO2Percent: 16.2
            )
        )

        XCTAssertEqual(viewModel.history.count, 1)
        XCTAssertEqual(viewModel.history[0].inputCo2ppm, 702, accuracy: 0.001)
        XCTAssertEqual(viewModel.history[0].outputCo2ppm, 618, accuracy: 0.001)
        XCTAssertEqual(viewModel.history[0].outputO2Percent, 16.2, accuracy: 0.001)
    }

    func test_receivedRapidSensorUpdates_mergeIntoSingleHistoryEntry() {
        let bluetoothManager = MockBluetoothManager()
        let viewModel = PhotobioreactorViewModel(
            bluetoothManager: bluetoothManager,
            shouldStartMockUpdates: false,
            shouldRequestNotificationPermission: false
        )

        bluetoothManager.emitUpdate(GroBotSensorUpdate(inputCo2ppm: 701))
        let historyCountAfterFirstUpdate = viewModel.history.count

        bluetoothManager.emitUpdate(GroBotSensorUpdate(outputCo2ppm: 552, outputO2Percent: 21.1))

        XCTAssertEqual(viewModel.history.count, historyCountAfterFirstUpdate)
        guard let latestReading = viewModel.history.last else {
            XCTFail("Expected a merged history reading")
            return
        }
        XCTAssertEqual(latestReading.inputCo2ppm, 701, accuracy: 0.001)
        XCTAssertEqual(latestReading.outputCo2ppm, 552, accuracy: 0.001)
        XCTAssertEqual(latestReading.outputO2Percent, 21.1, accuracy: 0.001)
    }
}

private func makeReading(
    timestamp: Date,
    inputCo2ppm: Double = 650,
    inputTemperatureC: Double = 24,
    inputHumidityPercent: Double = 52,
    outputCo2ppm: Double = 540,
    outputTemperatureC: Double = 24,
    outputHumidityPercent: Double = 52,
    outputO2Percent: Double = 20.9,
    airflowSlm: Double = 1.0
) -> ReactorReading {
    ReactorReading(
        timestamp: timestamp,
        inputCo2ppm: inputCo2ppm,
        inputTemperatureC: inputTemperatureC,
        inputHumidityPercent: inputHumidityPercent,
        outputCo2ppm: outputCo2ppm,
        outputTemperatureC: outputTemperatureC,
        outputHumidityPercent: outputHumidityPercent,
        outputO2Percent: outputO2Percent,
        airflowSlm: airflowSlm
    )
}
