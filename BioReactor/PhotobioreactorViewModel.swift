import Foundation
import SwiftUI
import Combine

struct ReactorReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let co2ppm: Double
    let o2ppm: Double
    let temperatureC: Double
    let humidityPercent: Double
}

final class PhotobioreactorViewModel: ObservableObject {
    @Published var currentReading: ReactorReading
    @Published var algaeHealth: String = "Good"
    @Published var pumpOn: Bool = true
    @Published var isConnected: Bool = false
    @Published var history: [ReactorReading] = []

    private var timer: Timer?

    init() {
        let initial = ReactorReading(
            timestamp: Date(),
            co2ppm: 650,
            o2ppm: 420,
            temperatureC: 24.0,
            humidityPercent: 52.0
        )

        self.currentReading = initial
        self.history = [initial]

        startMockUpdates()
    }

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
        let newO2 = max(200000, min(220000,
                                    currentReading.o2ppm + Double.random(in: -500...500)
                                ))
        let newTemp = max(18, min(32, currentReading.temperatureC + Double.random(in: -0.3...0.3)))
        let newHumidity = max(30, min(80, currentReading.humidityPercent + Double.random(in: -1.0...1.0)))

        let newReading = ReactorReading(
            timestamp: Date(),
            co2ppm: newCO2,
            o2ppm: newO2,
            temperatureC: newTemp,
            humidityPercent: newHumidity
        )

        currentReading = newReading
        history.append(newReading)

        if history.count > 60 {
            history.removeFirst()
        }

        updateAlgaeHealth(using: newReading)
    }

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
}//
//  PhotobioreactorViewModel.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//

