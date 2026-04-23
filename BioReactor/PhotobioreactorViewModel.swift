//
//  PhotobioreactorViewModel.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

struct ReactorReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let inputCo2ppm: Double
    let inputTemperatureC: Double
    let inputHumidityPercent: Double
    let outputCo2ppm: Double
    let outputTemperatureC: Double
    let outputHumidityPercent: Double
    let outputO2Percent: Double
    let airflowSlm: Double

    var co2ppm: Double { inputCo2ppm }
    var temperatureC: Double { inputTemperatureC }
    var humidityPercent: Double { inputHumidityPercent }

    func applying(_ update: GroBotSensorUpdate, at timestamp: Date = Date()) -> ReactorReading {
        ReactorReading(
            timestamp: timestamp,
            inputCo2ppm: update.inputCo2ppm ?? inputCo2ppm,
            inputTemperatureC: update.inputTemperatureC ?? inputTemperatureC,
            inputHumidityPercent: update.inputHumidityPercent ?? inputHumidityPercent,
            outputCo2ppm: update.outputCo2ppm ?? outputCo2ppm,
            outputTemperatureC: update.outputTemperatureC ?? outputTemperatureC,
            outputHumidityPercent: update.outputHumidityPercent ?? outputHumidityPercent,
            outputO2Percent: update.outputO2Percent ?? outputO2Percent,
            airflowSlm: update.airflowSlm ?? airflowSlm
        )
    }
}

struct AlertThresholds: Codable {
    var minTempC: Double = 20.0
    var maxTempC: Double = 30.0
    var maxCO2ppm: Double = 1200.0
    var minOutputO2Percent: Double = 19.5
    var minHumidityPercent: Double = 35.0
    var maxHumidityPercent: Double = 75.0

    enum CodingKeys: String, CodingKey {
        case minTempC
        case maxTempC
        case maxCO2ppm
        case minOutputO2Percent = "minO2ppm"
        case minHumidityPercent
        case maxHumidityPercent
    }
}

struct PumpSchedule: Codable {
    var isEnabled: Bool = false
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 17
    var endMinute: Int = 0
    var repeatDaily: Bool = true
}

struct LightSchedule: Codable {
    var isEnabled: Bool = false
    var startHour: Int = 8
    var startMinute: Int = 0
    var endHour: Int = 22
    var endMinute: Int = 0
    var repeatDaily: Bool = true
}

struct MaintenanceReminder: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var hour: Int
    var minute: Int
    var repeatsDaily: Bool
    var isEnabled: Bool = true
}


final class PhotobioreactorViewModel: ObservableObject {
    static let historyWindowDuration: TimeInterval = 60 * 60

    @Published var currentReading: ReactorReading
    @Published var algaeHealth: String = "Good"
    @Published var pumpOn: Bool = true
    @Published var isConnected: Bool = false
    @Published var bluetoothStatusMessage: String = "Not connected"
    @Published var discoveredDeviceName: String?
    @Published var isScanningForDevice: Bool = false
    @Published var history: [ReactorReading] = []

    @Published var thresholds = AlertThresholds()
    @Published var pumpSchedule = PumpSchedule()
    @Published var lightSchedule = LightSchedule()
    @Published var pumpPercent: Double = 70

   

    @Published var savedReminders: [MaintenanceReminder] = [
        MaintenanceReminder(
            title: "Harvest Algae",
            body: "Time to harvest algae from the reactor.",
            hour: 18,
            minute: 0,
            repeatsDaily: false,
            isEnabled: true
        ),
        MaintenanceReminder(
            title: "Remove Excess Algae",
            body: "Check reactor density and remove excess algae if needed.",
            hour: 19,
            minute: 0,
            repeatsDaily: false,
            isEnabled: false
        )
    ]

    @Published var activeAlerts: [String] = []

    private var timer: Timer?

    private let thresholdsKey = "pbr_alertThresholds"
    private let pumpScheduleKey = "pbr_pumpSchedule"
    private let lightScheduleKey = "pbr_lightSchedule"
    //private let dashboardRemindersKey = "pbr_dashboardReminders"
    private let savedRemindersKey = "pbr_savedReminders"
    private let bluetoothManager: GroBotBluetoothManaging
    private let shouldUseMockUpdates: Bool
    private let liveReadingMergeWindowSeconds: TimeInterval = 0.5

    private var hasSentLowTempAlert = false
    private var hasSentHighTempAlert = false
    private var hasSentHighCO2Alert = false
    private var hasSentLowO2Alert = false
    private var hasSentLowHumidityAlert = false
    private var hasSentHighHumidityAlert = false
    private var lastLiveReadingAt: Date?
    private var hasReceivedLiveReading = false

    var airQualityHistory: [ReactorReading] {
        Self.rollingHistoryWindow(from: history, duration: Self.historyWindowDuration)
    }

    init(
        bluetoothManager: GroBotBluetoothManaging = GroBotBluetoothManager(),
        shouldStartMockUpdates: Bool = true,
        shouldRequestNotificationPermission: Bool = true
    ) {
        self.bluetoothManager = bluetoothManager
        self.shouldUseMockUpdates = shouldStartMockUpdates

        let initial = ReactorReading(
            timestamp: Date(),
            inputCo2ppm: 650,
            inputTemperatureC: 24.0,
            inputHumidityPercent: 52.0,
            outputCo2ppm: 540,
            outputTemperatureC: 24.0,
            outputHumidityPercent: 52.0,
            outputO2Percent: 20.9,
            airflowSlm: .nan
        )

        self.currentReading = initial
        self.history = [initial]
        self.bluetoothManager.delegate = self

        loadSavedSettings()
        if shouldRequestNotificationPermission {
            requestNotificationPermission()
        }
        scheduleSavedReminderNotifications()
        updateAlgaeHealth(using: initial)
        evaluateThresholds(using: initial)

        if shouldStartMockUpdates {
            startMockUpdates()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Mock Data

    func startMockUpdates() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.generateNextReading()
            }
        }
    }

    func stopMockUpdates() {
        timer?.invalidate()
        timer = nil
    }

    private func generateNextReading() {
        let newInputCO2 = max(400, min(2000, currentReading.inputCo2ppm + Double.random(in: -25...25)))
        let newInputTemp = max(18, min(32, currentReading.inputTemperatureC + Double.random(in: -0.3...0.3)))
        let newInputHumidity = max(30, min(80, currentReading.inputHumidityPercent + Double.random(in: -1.0...1.0)))
        let newOutputCO2 = max(300, min(2000, currentReading.outputCo2ppm + Double.random(in: -30...30)))
        let newOutputTemp = max(18, min(32, currentReading.outputTemperatureC + Double.random(in: -0.3...0.3)))
        let newOutputHumidity = max(30, min(80, currentReading.outputHumidityPercent + Double.random(in: -1.0...1.0)))
        let newOutputO2 = max(0, min(100, currentReading.outputO2Percent + Double.random(in: -0.2...0.2)))
        let newAirflow = max(0, min(3, currentReading.airflowSlm.isFinite ? currentReading.airflowSlm + Double.random(in: -0.1...0.1) : 1.0))

        let newReading = ReactorReading(
            timestamp: Date(),
            inputCo2ppm: newInputCO2,
            inputTemperatureC: newInputTemp,
            inputHumidityPercent: newInputHumidity,
            outputCo2ppm: newOutputCO2,
            outputTemperatureC: newOutputTemp,
            outputHumidityPercent: newOutputHumidity,
            outputO2Percent: newOutputO2,
            airflowSlm: newAirflow
        )

        updateReading(newReading)
    }

    func scanForDevice() {
        bluetoothManager.startScan()
    }
    func setPumpEnabled(_ isOn: Bool) {
        let percent: UInt8 = isOn ? (pumpPercent > 0 ? UInt8(pumpPercent.rounded()) : 70) : 0
        setPumpPercent(percent)
    }
    func setPumpPercent(_ percent: UInt8) {
        let clamped = min(percent, 100)
        pumpPercent = Double(clamped)
        pumpOn = clamped > 0
        bluetoothManager.setPump(percent: clamped)
    }

    func updateReading(_ newReading: ReactorReading) {
        currentReading = newReading
        history.append(newReading)

        if history.count > 60 {
            history.removeFirst()
        }

        updateAlgaeHealth(using: newReading)
        evaluateThresholds(using: newReading)
    }

    static func rollingHistoryWindow(
        from history: [ReactorReading],
        duration: TimeInterval = historyWindowDuration
    ) -> [ReactorReading] {
        guard let latestTimestamp = history.map(\.timestamp).max() else {
            return []
        }

        let windowStart = latestTimestamp.addingTimeInterval(-duration)

        return history
            .filter { $0.timestamp >= windowStart && $0.timestamp <= latestTimestamp }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func applyLiveSensorUpdate(_ update: GroBotSensorUpdate) {
        let liveReading = currentReading.applying(update)
        currentReading = liveReading

        if !hasReceivedLiveReading {
            history = [liveReading]
            hasReceivedLiveReading = true
        } else if let lastLiveReadingAt,
           liveReading.timestamp.timeIntervalSince(lastLiveReadingAt) < liveReadingMergeWindowSeconds,
           !history.isEmpty {
            history[history.count - 1] = liveReading
        } else {
            history.append(liveReading)
            if history.count > 60 {
                history.removeFirst()
            }
        }

        lastLiveReadingAt = liveReading.timestamp
        if let pumpPercent = update.pumpPercent {
            let clamped = max(0.0, min(100.0, pumpPercent))
            self.pumpPercent = clamped
            self.pumpOn = clamped > 0
        }
        updateAlgaeHealth(using: liveReading)
        evaluateThresholds(using: liveReading)
    }

    // MARK: - Algae Health

    private func updateAlgaeHealth(using reading: ReactorReading) {
        if reading.inputCo2ppm >= 500 && reading.inputCo2ppm <= 1200 &&
            reading.inputTemperatureC >= 22 && reading.inputTemperatureC <= 28 &&
            reading.inputHumidityPercent >= 40 && reading.inputHumidityPercent <= 65 {
            algaeHealth = "Good"
        } else if reading.inputCo2ppm >= 450 && reading.inputCo2ppm <= 1500 &&
                    reading.inputTemperatureC >= 20 && reading.inputTemperatureC <= 30 &&
                    reading.inputHumidityPercent >= 35 && reading.inputHumidityPercent <= 75 {
            algaeHealth = "Monitor"
        } else {
            algaeHealth = "Poor"
        }
    }

    // MARK: - Alerts

    func evaluateThresholds(using reading: ReactorReading) {
        var alerts: [String] = []

        if reading.inputTemperatureC < thresholds.minTempC {
            alerts.append("Input temperature too low")
            if !hasSentLowTempAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Input temperature is too low: \(String(format: "%.1f", reading.inputTemperatureC))°C"
                )
                hasSentLowTempAlert = true
            }
        } else {
            hasSentLowTempAlert = false
        }

        if reading.inputTemperatureC > thresholds.maxTempC {
            alerts.append("Input temperature too high")
            if !hasSentHighTempAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Input temperature is too high: \(String(format: "%.1f", reading.inputTemperatureC))°C"
                )
                hasSentHighTempAlert = true
            }
        } else {
            hasSentHighTempAlert = false
        }

        if reading.inputCo2ppm > thresholds.maxCO2ppm {
            alerts.append("Input CO₂ too high")
            if !hasSentHighCO2Alert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Input CO₂ is too high: \(Int(reading.inputCo2ppm)) ppm"
                )
                hasSentHighCO2Alert = true
            }
        } else {
            hasSentHighCO2Alert = false
        }

        if reading.outputO2Percent < thresholds.minOutputO2Percent {
            alerts.append("Output O₂ too low")
            if !hasSentLowO2Alert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Output O₂ is too low: \(String(format: "%.1f", reading.outputO2Percent))%"
                )
                hasSentLowO2Alert = true
            }
        } else {
            hasSentLowO2Alert = false
        }

        if reading.inputHumidityPercent < thresholds.minHumidityPercent {
            alerts.append("Input humidity too low")
            if !hasSentLowHumidityAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Input humidity is too low: \(String(format: "%.1f", reading.inputHumidityPercent))%"
                )
                hasSentLowHumidityAlert = true
            }
        } else {
            hasSentLowHumidityAlert = false
        }

        if reading.inputHumidityPercent > thresholds.maxHumidityPercent {
            alerts.append("Input humidity too high")
            if !hasSentHighHumidityAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Input humidity is too high: \(String(format: "%.1f", reading.inputHumidityPercent))%"
                )
                hasSentHighHumidityAlert = true
            }
        } else {
            hasSentHighHumidityAlert = false
        }

        activeAlerts = alerts
    }

    func updateThresholds(
        minTempC: Double,
        maxTempC: Double,
        maxCO2ppm: Double,
        minOutputO2Percent: Double,
        minHumidityPercent: Double,
        maxHumidityPercent: Double
    ) {
        thresholds.minTempC = minTempC
        thresholds.maxTempC = maxTempC
        thresholds.maxCO2ppm = maxCO2ppm
        thresholds.minOutputO2Percent = minOutputO2Percent
        thresholds.minHumidityPercent = minHumidityPercent
        thresholds.maxHumidityPercent = maxHumidityPercent

        saveSettings()
        evaluateThresholds(using: currentReading)
    }

    // MARK: - Scheduling

    func updatePumpSchedule(
        isEnabled: Bool,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        repeatDaily: Bool
    ) {
        pumpSchedule.isEnabled = isEnabled
        pumpSchedule.startHour = startHour
        pumpSchedule.startMinute = startMinute
        pumpSchedule.endHour = endHour
        pumpSchedule.endMinute = endMinute
        pumpSchedule.repeatDaily = repeatDaily

        saveSettings()
    }

    func updateLightSchedule(
        isEnabled: Bool,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        repeatDaily: Bool
    ) {
        lightSchedule.isEnabled = isEnabled
        lightSchedule.startHour = startHour
        lightSchedule.startMinute = startMinute
        lightSchedule.endHour = endHour
        lightSchedule.endMinute = endMinute
        lightSchedule.repeatDaily = repeatDaily

        saveSettings()
    }

    // MARK: - Dashboard Reminders

    func addMaintenanceReminder(title: String, body: String, hour: Int, minute: Int, repeatsDaily: Bool) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else { return }

        let reminder = MaintenanceReminder(
            title: cleanTitle,
            body: cleanBody,
            hour: hour,
            minute: minute,
            repeatsDaily: repeatsDaily,
            isEnabled: true
        )

        savedReminders.append(reminder)
        saveSettings()
        scheduleSavedReminderNotifications()
    }

    /*func addReminderToDashboard(title: String, body: String, hour: Int, minute: Int, repeatsDaily: Bool) {
        let reminder = MaintenanceReminder(
            title: title,
            body: body,
            hour: hour,
            minute: minute,
            repeatsDaily: repeatsDaily,
            isEnabled: true
        )

        dashboardReminders.append(reminder)
        saveSettings()
    }

    // MARK: - Saved Reminders

    func saveReminderToControls(title: String, body: String, hour: Int, minute: Int, repeatsDaily: Bool) {
        let reminder = MaintenanceReminder(
            title: title,
            body: body,
            hour: hour,
            minute: minute,
            repeatsDaily: repeatsDaily,
            isEnabled: true
        )

        savedReminders.append(reminder)
        saveSettings()
        scheduleSavedReminderNotifications()
    }*/

    func deleteSavedReminder(at offsets: IndexSet) {
        let removed = offsets.map { savedReminders[$0] }

        for reminder in removed {
            removeNotification(id: notificationID(for: reminder))
        }

        savedReminders.remove(atOffsets: offsets)
        saveSettings()
    }

    func toggleSavedReminder(_ reminderID: UUID, isEnabled: Bool) {
        guard let index = savedReminders.firstIndex(where: { $0.id == reminderID }) else { return }

        savedReminders[index].isEnabled = isEnabled
        saveSettings()
        scheduleSavedReminderNotifications()
    }

    func scheduleSavedReminderNotifications() {
        for reminder in savedReminders {
            let id = notificationID(for: reminder)
            removeNotification(id: id)

            guard reminder.isEnabled else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: reminder.repeatsDaily
            )

            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    private func notificationID(for reminder: MaintenanceReminder) -> String {
        "maintenance_\(reminder.id.uuidString)"
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notifications granted: \(granted)")
            }
        }
    }

    private func sendImmediateNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func removeNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Persistence

    func saveSettings() {
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(thresholds) {
            UserDefaults.standard.set(data, forKey: thresholdsKey)
        }

        if let data = try? encoder.encode(pumpSchedule) {
            UserDefaults.standard.set(data, forKey: pumpScheduleKey)
        }

        if let data = try? encoder.encode(lightSchedule) {
            UserDefaults.standard.set(data, forKey: lightScheduleKey)
        }

        /*if let data = try? encoder.encode(dashboardReminders) {
            UserDefaults.standard.set(data, forKey: dashboardRemindersKey)
        }*/

        if let data = try? encoder.encode(savedReminders) {
            UserDefaults.standard.set(data, forKey: savedRemindersKey)
        }
    }

    private func loadSavedSettings() {
        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: thresholdsKey),
           let savedThresholds = try? decoder.decode(AlertThresholds.self, from: data) {
            thresholds = savedThresholds
        }

        if let data = UserDefaults.standard.data(forKey: pumpScheduleKey),
           let savedPumpSchedule = try? decoder.decode(PumpSchedule.self, from: data) {
            pumpSchedule = savedPumpSchedule
        }

        if let data = UserDefaults.standard.data(forKey: lightScheduleKey),
           let savedLightSchedule = try? decoder.decode(LightSchedule.self, from: data) {
            lightSchedule = savedLightSchedule
        }

        /*if let data = UserDefaults.standard.data(forKey: dashboardRemindersKey),
           let loadedDashboardReminders = try? decoder.decode([MaintenanceReminder].self, from: data) {
            dashboardReminders = loadedDashboardReminders
        }*/

        if let data = UserDefaults.standard.data(forKey: savedRemindersKey),
           let loadedSavedReminders = try? decoder.decode([MaintenanceReminder].self, from: data) {
            savedReminders = loadedSavedReminders
        }
    }

    // MARK: - Debug Helpers

    func triggerHighTempTest() {
        let reading = ReactorReading(
            timestamp: Date(),
            inputCo2ppm: currentReading.inputCo2ppm,
            inputTemperatureC: thresholds.maxTempC + 3.0,
            inputHumidityPercent: currentReading.inputHumidityPercent,
            outputCo2ppm: currentReading.outputCo2ppm,
            outputTemperatureC: currentReading.outputTemperatureC,
            outputHumidityPercent: currentReading.outputHumidityPercent,
            outputO2Percent: currentReading.outputO2Percent,
            airflowSlm: currentReading.airflowSlm
        )
        updateReading(reading)
    }

    func triggerHighCO2Test() {
        let reading = ReactorReading(
            timestamp: Date(),
            inputCo2ppm: thresholds.maxCO2ppm + 300.0,
            inputTemperatureC: currentReading.inputTemperatureC,
            inputHumidityPercent: currentReading.inputHumidityPercent,
            outputCo2ppm: currentReading.outputCo2ppm,
            outputTemperatureC: currentReading.outputTemperatureC,
            outputHumidityPercent: currentReading.outputHumidityPercent,
            outputO2Percent: currentReading.outputO2Percent,
            airflowSlm: currentReading.airflowSlm
        )
        updateReading(reading)
    }

    func triggerLowO2Test() {
        let reading = ReactorReading(
            timestamp: Date(),
            inputCo2ppm: currentReading.inputCo2ppm,
            inputTemperatureC: currentReading.inputTemperatureC,
            inputHumidityPercent: currentReading.inputHumidityPercent,
            outputCo2ppm: currentReading.outputCo2ppm,
            outputTemperatureC: currentReading.outputTemperatureC,
            outputHumidityPercent: currentReading.outputHumidityPercent,
            outputO2Percent: thresholds.minOutputO2Percent - 1.0,
            airflowSlm: currentReading.airflowSlm
        )
        updateReading(reading)
    }

    func triggerLowHumidityTest() {
        let reading = ReactorReading(
            timestamp: Date(),
            inputCo2ppm: currentReading.inputCo2ppm,
            inputTemperatureC: currentReading.inputTemperatureC,
            inputHumidityPercent: thresholds.minHumidityPercent - 5.0,
            outputCo2ppm: currentReading.outputCo2ppm,
            outputTemperatureC: currentReading.outputTemperatureC,
            outputHumidityPercent: currentReading.outputHumidityPercent,
            outputO2Percent: currentReading.outputO2Percent,
            airflowSlm: currentReading.airflowSlm
        )
        updateReading(reading)
    }
}

extension PhotobioreactorViewModel: GroBotBluetoothManagerDelegate {
    func bluetoothManager(_ manager: GroBotBluetoothManaging, didChangeStatus status: GroBotBluetoothStatus) {
        switch status {
        case .idle:
            isScanningForDevice = false
            isConnected = false
            bluetoothStatusMessage = discoveredDeviceName == nil
                ? "Not connected"
                : "Disconnected from \(discoveredDeviceName!)"
            if shouldUseMockUpdates {
                startMockUpdates()
            }

        case .scanning:
            isScanningForDevice = true
            isConnected = false
            bluetoothStatusMessage = "Scanning for Gro-Bot..."

        case .connecting(let deviceName):
            isScanningForDevice = false
            isConnected = false
            discoveredDeviceName = deviceName
            bluetoothStatusMessage = "Connecting to \(deviceName)..."

        case .connected(let deviceName):
            isScanningForDevice = false
            isConnected = true
            discoveredDeviceName = deviceName
            bluetoothStatusMessage = "Connected to \(deviceName)"
            stopMockUpdates()

        case .failed(let message):
            isScanningForDevice = false
            isConnected = false
            bluetoothStatusMessage = message
            if shouldUseMockUpdates {
                startMockUpdates()
            }
        }
    }

    func bluetoothManager(_ manager: GroBotBluetoothManaging, didReceiveSensorUpdate update: GroBotSensorUpdate) {
        applyLiveSensorUpdate(update)
    }
}
