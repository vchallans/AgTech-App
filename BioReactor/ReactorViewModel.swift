import Foundation
import SwiftUI
import Combine

final class ReactorViewModel: ObservableObject {
    @Published var currentReading = ReactorReading(
        timestamp: Date(),
        inputCo2ppm: 650,
        inputTemperatureC: 25,
        inputHumidityPercent: 50,
        outputCo2ppm: 540,
        outputTemperatureC: 25,
        outputHumidityPercent: 50,
        outputO2Percent: 20.9,
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
        let newInputCO2 = max(400, min(2000, currentReading.inputCo2ppm + co2Delta))
        let newOutputCO2 = max(300, min(2000, currentReading.outputCo2ppm + co2Delta))
        let newOutputO2 = max(0, min(100, currentReading.outputO2Percent + Double.random(in: -0.2...0.2)))
        let newInputTemp = max(18, min(32, currentReading.inputTemperatureC + Double.random(in: -0.3...0.3)))
        let newInputHumidity = max(30, min(80, currentReading.inputHumidityPercent + Double.random(in: -1.0...1.0)))
        let newOutputTemp = max(18, min(32, currentReading.outputTemperatureC + Double.random(in: -0.3...0.3)))
        let newOutputHumidity = max(30, min(80, currentReading.outputHumidityPercent + Double.random(in: -1.0...1.0)))
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
