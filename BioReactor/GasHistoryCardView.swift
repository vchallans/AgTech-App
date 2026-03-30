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

    private var baselineCO2: Double {
        history.first?.co2ppm ?? 1
    }

    private var baselineO2: Double {
        history.first?.o2ppm ?? 1
    }

    private var latestReading: ReactorReading? {
        history.last
    }

    private var trendText: String {
        guard history.count >= 2 else { return "Collecting data..." }

        let previous = history[history.count - 2]
        let latest = history[history.count - 1]

        if latest.co2ppm < previous.co2ppm && latest.o2ppm > previous.o2ppm {
            return "Photosynthesis trend: CO₂ down, O₂ up"
        } else if latest.co2ppm > previous.co2ppm && latest.o2ppm < previous.o2ppm {
            return "Respiration trend: CO₂ up, O₂ down"
        } else {
            return "Gas balance stable"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CO₂ vs O₂ History")
                    .font(.headline)

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.secondary)
            }

            if let latest = latestReading {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CO₂")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(latest.co2ppm)) ppm")
                            .font(.title3.weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("O₂")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(latest.o2ppm)) ppm")
                            .font(.title3.weight(.semibold))
                    }
                }
            }

            if history.count > 1 {
                Chart {
                    ForEach(history) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("CO₂ (% baseline)", (reading.co2ppm / baselineCO2) * 100)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("CO₂ (% baseline)", (reading.co2ppm / baselineCO2) * 100)
                        )
                        .foregroundStyle(.green)

                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("O₂ (% baseline)", (reading.o2ppm / baselineO2) * 100)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("O₂ (% baseline)", (reading.o2ppm / baselineO2) * 100)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("Normalized %", position: .leading)
            } else {
                ContentUnavailableView(
                    "Not enough history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Generate more readings to see the trend.")
                )
                .frame(height: 220)
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                    Text("CO₂")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 10, height: 10)
                    Text("O₂")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(trendText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
}
