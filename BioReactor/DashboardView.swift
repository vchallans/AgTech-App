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

                Text("CO₂: \(Int(viewModel.currentReading.co2ppm)) ppm")
                Text("O₂: \(Int(viewModel.currentReading.o2ppm)) ppm")
                Text("Temp: \(viewModel.currentReading.temperatureC, specifier: "%.1f") °C")
                Text("Humidity: \(viewModel.currentReading.humidityPercent, specifier: "%.1f") %")

                Text("Algae Health: \(viewModel.algaeHealth)")
                    .foregroundColor(healthColor)
                    .font(.headline)

                //GasHistoryCardView(history: viewModel.history)
            }
            .padding()
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
}
