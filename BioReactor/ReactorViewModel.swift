import Foundation
import SwiftUI
import Combine

final class ReactorViewModel: ObservableObject {
    @Published var currentReading = ReactorReading(
        timestamp: Date(),
        co2ppm: 650,
        o2ppm: 210000,
        temperatureC: 25,
        humidityPercent: 50,
        airflowSlm: .nan
    )

    @Published var history: [ReactorReading] = []

    private var timer: Timer?

    init() {
        history = [currentReading]
    }

    func startMockUpdates() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.generateNextReading()
            }
        }
    }

    func stopMockUpdates() {
        timer?.invalidate()
        timer = nil
    }

    private func generateNextReading() {
        let co2Delta = Double.random(in: -25...25)
        let newCO2 = max(400, min(2000, currentReading.co2ppm + co2Delta))

        let o2Delta = -co2Delta * 8 + Double.random(in: -50...50)
        let newO2 = max(200000, min(220000, currentReading.o2ppm + o2Delta))

        let newTemp = max(18, min(32, currentReading.temperatureC + Double.random(in: -0.3...0.3)))
        let newHumidity = max(30, min(80, currentReading.humidityPercent + Double.random(in: -1.0...1.0)))
        let newAirflow = max(0, min(3, currentReading.airflowSlm.isFinite ? currentReading.airflowSlm + Double.random(in: -0.1...0.1) : 1.0))

        let newReading = ReactorReading(
            timestamp: Date(),
            co2ppm: newCO2,
            o2ppm: newO2,
            temperatureC: newTemp,
            humidityPercent: newHumidity,
            airflowSlm: newAirflow
        )

        currentReading = newReading
        history.append(newReading)

        if history.count > 60 {
            history.removeFirst()
        }
    }
}
//  ReactorViewModel.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/26/26.
//
