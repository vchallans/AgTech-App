//
//  ControlsView 2.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//


import SwiftUI

struct ControlsView: View {
    @ObservedObject var viewModel: PhotobioreactorViewModel

    var body: some View {
        VStack(spacing: 20) {
            Toggle("Air Pump", isOn: $viewModel.pumpOn)

            Button("Calibrate Sensor") {
                print("Calibrating...")
            }

            Text("Pump is currently \(viewModel.pumpOn ? "On" : "Off")")
        }
        .padding()
    }
}
