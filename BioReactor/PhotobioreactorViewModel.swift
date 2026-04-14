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
    let co2ppm: Double
    let o2ppm: Double
    let temperatureC: Double
    let humidityPercent: Double
}

struct AlertThresholds: Codable {
    var minTempC: Double = 20.0
    var maxTempC: Double = 30.0
    var maxCO2ppm: Double = 1200.0
    var minO2ppm: Double = 200000.0
    var minHumidityPercent: Double = 35.0
    var maxHumidityPercent: Double = 75.0
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
    @Published var currentReading: ReactorReading
    @Published var algaeHealth: String = "Good"
    @Published var pumpOn: Bool = true
    @Published var isConnected: Bool = false
    @Published var history: [ReactorReading] = []

    @Published var thresholds = AlertThresholds()
    @Published var pumpSchedule = PumpSchedule()
    @Published var lightSchedule = LightSchedule()

    @Published var dashboardReminders: [MaintenanceReminder] = [
        MaintenanceReminder(
            title: "Harvest Algae",
            body: "Time to harvest algae from the reactor.",
            hour: 18,
            minute: 0,
            repeatsDaily: false,
            isEnabled: true
        )
    ]

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
    private let dashboardRemindersKey = "pbr_dashboardReminders"
    private let savedRemindersKey = "pbr_savedReminders"

    private var hasSentLowTempAlert = false
    private var hasSentHighTempAlert = false
    private var hasSentHighCO2Alert = false
    private var hasSentLowO2Alert = false
    private var hasSentLowHumidityAlert = false
    private var hasSentHighHumidityAlert = false

    init() {
        let initial = ReactorReading(
            timestamp: Date(),
            co2ppm: 650,
            o2ppm: 210000,
            temperatureC: 24.0,
            humidityPercent: 52.0
        )

        self.currentReading = initial
        self.history = [initial]

        loadSavedSettings()
        requestNotificationPermission()
        scheduleSavedReminderNotifications()
        updateAlgaeHealth(using: initial)
        evaluateThresholds(using: initial)

        startMockUpdates()
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
        let newCO2 = max(400, min(2000, currentReading.co2ppm + Double.random(in: -25...25)))
        let newO2 = max(200000, min(220000, currentReading.o2ppm + Double.random(in: -500...500)))
        let newTemp = max(18, min(32, currentReading.temperatureC + Double.random(in: -0.3...0.3)))
        let newHumidity = max(30, min(80, currentReading.humidityPercent + Double.random(in: -1.0...1.0)))

        let newReading = ReactorReading(
            timestamp: Date(),
            co2ppm: newCO2,
            o2ppm: newO2,
            temperatureC: newTemp,
            humidityPercent: newHumidity
        )

        updateReading(newReading)
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

    // MARK: - Algae Health

    private func updateAlgaeHealth(using reading: ReactorReading) {
        if reading.co2ppm >= 500 && reading.co2ppm <= 1200 &&
            reading.temperatureC >= 22 && reading.temperatureC <= 28 &&
            reading.humidityPercent >= 40 && reading.humidityPercent <= 65 {
            algaeHealth = "Good"
        } else if reading.co2ppm >= 450 && reading.co2ppm <= 1500 &&
                    reading.temperatureC >= 20 && reading.temperatureC <= 30 &&
                    reading.humidityPercent >= 35 && reading.humidityPercent <= 75 {
            algaeHealth = "Monitor"
        } else {
            algaeHealth = "Poor"
        }
    }

    // MARK: - Alerts

    func evaluateThresholds(using reading: ReactorReading) {
        var alerts: [String] = []

        if reading.temperatureC < thresholds.minTempC {
            alerts.append("Temperature too low")
            if !hasSentLowTempAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Temperature is too low: \(String(format: "%.1f", reading.temperatureC))°C"
                )
                hasSentLowTempAlert = true
            }
        } else {
            hasSentLowTempAlert = false
        }

        if reading.temperatureC > thresholds.maxTempC {
            alerts.append("Temperature too high")
            if !hasSentHighTempAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Temperature is too high: \(String(format: "%.1f", reading.temperatureC))°C"
                )
                hasSentHighTempAlert = true
            }
        } else {
            hasSentHighTempAlert = false
        }

        if reading.co2ppm > thresholds.maxCO2ppm {
            alerts.append("CO₂ too high")
            if !hasSentHighCO2Alert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "CO₂ is too high: \(Int(reading.co2ppm)) ppm"
                )
                hasSentHighCO2Alert = true
            }
        } else {
            hasSentHighCO2Alert = false
        }

        if reading.o2ppm < thresholds.minO2ppm {
            alerts.append("O₂ too low")
            if !hasSentLowO2Alert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "O₂ is too low: \(Int(reading.o2ppm)) ppm"
                )
                hasSentLowO2Alert = true
            }
        } else {
            hasSentLowO2Alert = false
        }

        if reading.humidityPercent < thresholds.minHumidityPercent {
            alerts.append("Humidity too low")
            if !hasSentLowHumidityAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Humidity is too low: \(String(format: "%.1f", reading.humidityPercent))%"
                )
                hasSentLowHumidityAlert = true
            }
        } else {
            hasSentLowHumidityAlert = false
        }

        if reading.humidityPercent > thresholds.maxHumidityPercent {
            alerts.append("Humidity too high")
            if !hasSentHighHumidityAlert {
                sendImmediateNotification(
                    title: "Bioreactor Alert",
                    body: "Humidity is too high: \(String(format: "%.1f", reading.humidityPercent))%"
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
        minO2ppm: Double,
        minHumidityPercent: Double,
        maxHumidityPercent: Double
    ) {
        thresholds.minTempC = minTempC
        thresholds.maxTempC = maxTempC
        thresholds.maxCO2ppm = maxCO2ppm
        thresholds.minO2ppm = minO2ppm
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

    func addReminderToDashboard(title: String, body: String, hour: Int, minute: Int, repeatsDaily: Bool) {
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
    }

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

        if let data = try? encoder.encode(dashboardReminders) {
            UserDefaults.standard.set(data, forKey: dashboardRemindersKey)
        }

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

        if let data = UserDefaults.standard.data(forKey: dashboardRemindersKey),
           let loadedDashboardReminders = try? decoder.decode([MaintenanceReminder].self, from: data) {
            dashboardReminders = loadedDashboardReminders
        }

        if let data = UserDefaults.standard.data(forKey: savedRemindersKey),
           let loadedSavedReminders = try? decoder.decode([MaintenanceReminder].self, from: data) {
            savedReminders = loadedSavedReminders
        }
    }

    // MARK: - Debug Helpers

    func triggerHighTempTest() {
        let reading = ReactorReading(
            timestamp: Date(),
            co2ppm: currentReading.co2ppm,
            o2ppm: currentReading.o2ppm,
            temperatureC: thresholds.maxTempC + 3.0,
            humidityPercent: currentReading.humidityPercent
        )
        updateReading(reading)
    }

    func triggerHighCO2Test() {
        let reading = ReactorReading(
            timestamp: Date(),
            co2ppm: thresholds.maxCO2ppm + 300.0,
            o2ppm: currentReading.o2ppm,
            temperatureC: currentReading.temperatureC,
            humidityPercent: currentReading.humidityPercent
        )
        updateReading(reading)
    }

    func triggerLowO2Test() {
        let reading = ReactorReading(
            timestamp: Date(),
            co2ppm: currentReading.co2ppm,
            o2ppm: thresholds.minO2ppm - 5000.0,
            temperatureC: currentReading.temperatureC,
            humidityPercent: currentReading.humidityPercent
        )
        updateReading(reading)
    }

    func triggerLowHumidityTest() {
        let reading = ReactorReading(
            timestamp: Date(),
            co2ppm: currentReading.co2ppm,
            o2ppm: currentReading.o2ppm,
            temperatureC: currentReading.temperatureC,
            humidityPercent: thresholds.minHumidityPercent - 5.0
        )
        updateReading(reading)
    }
}
