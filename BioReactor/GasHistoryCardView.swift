//
//  GasHistoryCardView.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/26/26.
//
import SwiftUI
import Charts

struct GasHistoryCardView: View {
    let history: [ReactorReading]

    private var earliestTimestamp: Date? {
        history.first?.timestamp
    }

    private var latestTimestamp: Date? {
        history.last?.timestamp
    }

    private var timeWindowText: String {
        guard let earliestTimestamp, let latestTimestamp else {
            return "Waiting for air quality samples"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: earliestTimestamp)) to \(formatter.string(from: latestTimestamp))"
    }

    private var timeSpan: TimeInterval {
        guard let earliestTimestamp, let latestTimestamp else {
            return 0
        }

        return latestTimestamp.timeIntervalSince(earliestTimestamp)
    }

    private var timeDomain: ClosedRange<Date> {
        guard let earliestTimestamp, let latestTimestamp else {
            let now = Date()
            return now...now.addingTimeInterval(60)
        }

        if earliestTimestamp == latestTimestamp {
            return earliestTimestamp.addingTimeInterval(-30)...latestTimestamp.addingTimeInterval(30)
        }

        return earliestTimestamp...latestTimestamp
    }

    private var xAxisValues: [Date] {
        guard let earliestTimestamp else {
            return []
        }

        guard timeSpan > 0 else {
            return [earliestTimestamp]
        }

        let segments = 3
        return (0...segments).map { index in
            earliestTimestamp.addingTimeInterval(timeSpan * Double(index) / Double(segments))
        }
    }

    private var co2Domain: ClosedRange<Double> {
        let values = history.flatMap { reading -> [Double] in
            [
                reading.inputCo2ppm,
                reading.outputCo2ppm,
            ]
        }

        return rawDomain(for: values, minimumPadding: 20)
    }

    private var o2Domain: ClosedRange<Double> {
        let values = history.map(\.outputO2Percent)

        return rawDomain(for: values, minimumPadding: 0.4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Air Quality History")
                        .font(.headline)

                    Text("Up to the last hour of readings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(.secondary)

                    Text(timeWindowText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if history.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("CO₂ Comparison")
                        .font(.headline)

                    Chart {
                        ForEach(history) { reading in
                            LineMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("Input CO₂", reading.inputCo2ppm)
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.linear)

                            LineMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("Output CO₂", reading.outputCo2ppm)
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .interpolationMethod(.linear)
                        }
                    }
                    .frame(height: 220)
                    .chartXScale(domain: timeDomain)
                    .chartXAxis {
                        AxisMarks(values: xAxisValues) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.hour().minute())
                                }
                            }
                        }
                    }
                    .chartYScale(domain: co2Domain)
                    .chartYAxisLabel("ppm", position: .leading)

                    HStack(spacing: 14) {
                        legendItem(color: .green, label: "Input CO₂")
                        legendItem(color: .orange, label: "Output CO₂")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Output O₂")
                        .font(.headline)

                    Chart {
                        ForEach(history) { reading in
                            LineMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("Output O₂", reading.outputO2Percent)
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.linear)
                        }
                    }
                    .frame(height: 180)
                    .chartXScale(domain: timeDomain)
                    .chartXAxis {
                        AxisMarks(values: xAxisValues) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.hour().minute())
                                }
                            }
                        }
                    }
                    .chartYScale(domain: o2Domain)
                    .chartYAxisLabel("%", position: .leading)

                    HStack(spacing: 14) {
                        legendItem(color: .blue, label: "Output O₂")
                    }
                }
            } else {
                ContentUnavailableView(
                    "Not enough history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Generate more air quality readings in the last hour to see the trend.")
                )
                .frame(height: 220)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rawDomain(
        for values: [Double],
        minimumPadding: Double
    ) -> ClosedRange<Double> {
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...1
        }

        let span = maxValue - minValue
        let padding = max(span * 0.18, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }
}
