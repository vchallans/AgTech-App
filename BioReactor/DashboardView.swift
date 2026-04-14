//
//  DashboardView.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//


import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: PhotobioreactorViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Photobioreactor")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    readingRow(title: "CO₂", value: "\(Int(viewModel.currentReading.co2ppm)) ppm")
                    readingRow(title: "O₂", value: "\(Int(viewModel.currentReading.o2ppm)) ppm")
                    readingRow(title: "Temperature", value: "\(String(format: "%.1f", viewModel.currentReading.temperatureC)) °C")
                    readingRow(title: "Humidity", value: "\"\(String(format: "%.1f", viewModel.currentReading.humidityPercent)) %")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                VStack(spacing: 8) {
                    Text("Algae Health")
                        .font(.headline)

                    Text(viewModel.algaeHealth)
                        .foregroundColor(healthColor)
                        .font(.title3.bold())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Active Alerts")
                        .font(.headline)

                    if viewModel.activeAlerts.isEmpty {
                        Text("All readings are within the current threshold ranges.")
                            .foregroundColor(.green)
                    } else {
                        ForEach(viewModel.activeAlerts, id: \.self) { alert in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)

                                Text(alert)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Schedules")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Air Pump")
                            .font(.subheadline.bold())

                        Text(scheduleText(
                            enabled: viewModel.pumpSchedule.isEnabled,
                            startHour: viewModel.pumpSchedule.startHour,
                            startMinute: viewModel.pumpSchedule.startMinute,
                            endHour: viewModel.pumpSchedule.endHour,
                            endMinute: viewModel.pumpSchedule.endMinute
                        ))
                        .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Light Cycle")
                            .font(.subheadline.bold())

                        Text(scheduleText(
                            enabled: viewModel.lightSchedule.isEnabled,
                            startHour: viewModel.lightSchedule.startHour,
                            startMinute: viewModel.lightSchedule.startMinute,
                            endHour: viewModel.lightSchedule.endHour,
                            endMinute: viewModel.lightSchedule.endMinute
                        ))
                        .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Maintenance Reminders")
                        .font(.headline)

                    if viewModel.dashboardReminders.filter({ $0.isEnabled }).isEmpty {
                        Text("No enabled reminders.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.dashboardReminders.filter { $0.isEnabled }) { reminder in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title)
                                    .font(.subheadline.bold())

                                Text(reminder.body)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(reminderTimeText(reminder))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Uncomment this again if your history card is working
                // GasHistoryCardView(history: viewModel.history)
            }
            .padding()
        }
    }

    private func readingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private var healthColor: Color {
        switch viewModel.algaeHealth {
        case "Good":
            return .green
        case "Monitor":
            return .orange
        default:
            return .red
        }
    }

    private func scheduleText(
        enabled: Bool,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> String {
        guard enabled else { return "Disabled" }

        return "\(formattedTime(hour: startHour, minute: startMinute)) to \(formattedTime(hour: endHour, minute: endMinute))"
    }

    private func reminderTimeText(_ reminder: MaintenanceReminder) -> String {
        let timeString = formattedTime(hour: reminder.hour, minute: reminder.minute)
        return reminder.repeatsDaily ? "\(timeString) • Repeats daily" : "\(timeString) • One-time reminder"
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
