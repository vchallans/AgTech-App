//
//  ControlsView 2.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//

import SwiftUI

struct ControlsView: View {
    @ObservedObject var viewModel: PhotobioreactorViewModel

    @FocusState private var isInputFocused: Bool

    @State private var minTempC: String = ""
    @State private var maxTempC: String = ""
    @State private var maxCO2ppm: String = ""
    @State private var minOutputO2Percent: String = ""
    @State private var minHumidity: String = ""
    @State private var maxHumidity: String = ""

    @State private var pumpStart = Date()
    @State private var pumpEnd = Date()
    @State private var lightStart = Date()
    @State private var lightEnd = Date()

    @State private var reminderTitle: String = ""
    @State private var reminderBody: String = ""
    @State private var reminderTime = Date()
    @State private var reminderRepeatsDaily = false

    var body: some View {
        NavigationView {
            Form {
                Section("Air Pump Manual Control") {
                    Toggle("Air Pump", isOn: $viewModel.pumpOn)

                    Text("Pump is currently \(viewModel.pumpOn ? "On" : "Off")")
                        .foregroundColor(.secondary)

                    Button("Calibrate Sensor") {
                        isInputFocused = false
                        print("Calibrating...")
                    }
                }

                Section("Alert Thresholds") {
                    HStack {
                        Text("Min Temp (°C)")
                        Spacer()
                        TextField("20.0", text: $minTempC)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                    }

                    HStack {
                        Text("Max Temp (°C)")
                        Spacer()
                        TextField("30.0", text: $maxTempC)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                    }

                    HStack {
                        Text("Max Input CO₂ (ppm)")
                        Spacer()
                        TextField("1200", text: $maxCO2ppm)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                    }

                    HStack {
                        Text("Min Output O₂ (%)")
                        Spacer()
                        TextField("19.5", text: $minOutputO2Percent)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                    }

                    HStack {
                        Text("Min Humidity (%)")
                        Spacer()
                        TextField("35", text: $minHumidity)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                    }

                    HStack {
                        Text("Max Humidity (%)")
                        Spacer()
                        TextField("75", text: $maxHumidity)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                    }

                    Button("Save Thresholds") {
                        isInputFocused = false
                        saveThresholds()
                    }
                }

                Section("Air Pump Schedule") {
                    Toggle("Enable Pump Schedule", isOn: $viewModel.pumpSchedule.isEnabled)

                    DatePicker("Start Time", selection: $pumpStart, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $pumpEnd, displayedComponents: .hourAndMinute)

                    Toggle("Repeat Daily", isOn: $viewModel.pumpSchedule.repeatDaily)

                    Button("Save Pump Schedule") {
                        isInputFocused = false

                        let start = Calendar.current.dateComponents([.hour, .minute], from: pumpStart)
                        let end = Calendar.current.dateComponents([.hour, .minute], from: pumpEnd)

                        viewModel.updatePumpSchedule(
                            isEnabled: viewModel.pumpSchedule.isEnabled,
                            startHour: start.hour ?? 0,
                            startMinute: start.minute ?? 0,
                            endHour: end.hour ?? 0,
                            endMinute: end.minute ?? 0,
                            repeatDaily: viewModel.pumpSchedule.repeatDaily
                        )
                    }
                }

                Section("Light / Dark Cycle") {
                    Toggle("Enable Light Schedule", isOn: $viewModel.lightSchedule.isEnabled)

                    DatePicker("Lights On", selection: $lightStart, displayedComponents: .hourAndMinute)
                    DatePicker("Lights Off", selection: $lightEnd, displayedComponents: .hourAndMinute)

                    Toggle("Repeat Daily", isOn: $viewModel.lightSchedule.repeatDaily)

                    Button("Save Light Schedule") {
                        isInputFocused = false

                        let start = Calendar.current.dateComponents([.hour, .minute], from: lightStart)
                        let end = Calendar.current.dateComponents([.hour, .minute], from: lightEnd)

                        viewModel.updateLightSchedule(
                            isEnabled: viewModel.lightSchedule.isEnabled,
                            startHour: start.hour ?? 0,
                            startMinute: start.minute ?? 0,
                            endHour: end.hour ?? 0,
                            endMinute: end.minute ?? 0,
                            repeatDaily: viewModel.lightSchedule.repeatDaily
                        )
                    }
                }

                Section("Create Maintenance Reminder") {
                    TextField("Reminder Title", text: $reminderTitle)
                        .focused($isInputFocused)

                    TextField("Reminder Description", text: $reminderBody)
                        .focused($isInputFocused)

                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)

                    Toggle("Repeat Daily", isOn: $reminderRepeatsDaily)

                    Button("Add Reminder") {
                        addReminderToDashboard()
                    }
                    .disabled(reminderFieldsAreInvalid)

                    Button("Save Reminder") {
                        saveReminderToControls()
                    }
                    .disabled(reminderFieldsAreInvalid)
                }

                Section("Saved Reminders") {
                    if viewModel.savedReminders.isEmpty {
                        Text("No reminders saved yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.savedReminders) { reminder in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(reminder.title)
                                        .font(.headline)

                                    Spacer()

                                    Text(formattedTime(hour: reminder.hour, minute: reminder.minute))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if !reminder.body.isEmpty {
                                    Text(reminder.body)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text(reminder.repeatsDaily ? "Repeats daily" : "One-time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Toggle(
                                        "Enabled",
                                        isOn: Binding(
                                            get: { reminder.isEnabled },
                                            set: { newValue in
                                                viewModel.toggleSavedReminder(reminder.id, isEnabled: newValue)
                                            }
                                        )
                                    )
                                    .labelsHidden()
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteSavedReminder(reminder.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Debug Alerts") {
                    Button("Trigger High Temp Test") {
                        isInputFocused = false
                        viewModel.triggerHighTempTest()
                    }

                    Button("Trigger High Input CO₂ Test") {
                        isInputFocused = false
                        viewModel.triggerHighCO2Test()
                    }

                    Button("Trigger Low Output O₂ Test") {
                        isInputFocused = false
                        viewModel.triggerLowO2Test()
                    }

                    Button("Trigger Low Humidity Test") {
                        isInputFocused = false
                        viewModel.triggerLowHumidityTest()
                    }
                }
            }
            .navigationTitle("Controls")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                }
            }
            .onTapGesture {
                isInputFocused = false
            }
            .onAppear {
                loadFromViewModel()
            }
        }
    }

    private var reminderFieldsAreInvalid: Bool {
        reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        reminderBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReminderToDashboard() {
        isInputFocused = false

        let cleanTitle = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = reminderBody.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanBody.isEmpty else { return }

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)

        viewModel.addReminderToDashboard(
            title: cleanTitle,
            body: cleanBody,
            hour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            repeatsDaily: reminderRepeatsDaily
        )

        clearReminderFields()
    }

    private func saveReminderToControls() {
        isInputFocused = false

        let cleanTitle = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = reminderBody.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanBody.isEmpty else { return }

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)

        viewModel.saveReminderToControls(
            title: cleanTitle,
            body: cleanBody,
            hour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            repeatsDaily: reminderRepeatsDaily
        )

        clearReminderFields()
    }

    private func clearReminderFields() {
        reminderTitle = ""
        reminderBody = ""
        reminderRepeatsDaily = false
        reminderTime = Date()
    }

    private func deleteSavedReminder(_ id: UUID) {
        guard let index = viewModel.savedReminders.firstIndex(where: { $0.id == id }) else { return }
        viewModel.deleteSavedReminder(at: IndexSet(integer: index))
    }

    private func loadFromViewModel() {
        minTempC = String(viewModel.thresholds.minTempC)
        maxTempC = String(viewModel.thresholds.maxTempC)
        maxCO2ppm = String(viewModel.thresholds.maxCO2ppm)
        minOutputO2Percent = String(viewModel.thresholds.minOutputO2Percent)
        minHumidity = String(viewModel.thresholds.minHumidityPercent)
        maxHumidity = String(viewModel.thresholds.maxHumidityPercent)

        pumpStart = makeDate(
            hour: viewModel.pumpSchedule.startHour,
            minute: viewModel.pumpSchedule.startMinute
        )
        pumpEnd = makeDate(
            hour: viewModel.pumpSchedule.endHour,
            minute: viewModel.pumpSchedule.endMinute
        )

        lightStart = makeDate(
            hour: viewModel.lightSchedule.startHour,
            minute: viewModel.lightSchedule.startMinute
        )
        lightEnd = makeDate(
            hour: viewModel.lightSchedule.endHour,
            minute: viewModel.lightSchedule.endMinute
        )
    }

    private func saveThresholds() {
        guard
            let minTemp = Double(minTempC),
            let maxTemp = Double(maxTempC),
            let maxCO2 = Double(maxCO2ppm),
            let minO2 = Double(minOutputO2Percent),
            let minHum = Double(minHumidity),
            let maxHum = Double(maxHumidity)
        else {
            return
        }

        viewModel.updateThresholds(
            minTempC: minTemp,
            maxTempC: maxTemp,
            maxCO2ppm: maxCO2,
            minOutputO2Percent: minO2,
            minHumidityPercent: minHum,
            maxHumidityPercent: maxHum
        )
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let date = Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()

        return formatter.string(from: date)
    }
}
