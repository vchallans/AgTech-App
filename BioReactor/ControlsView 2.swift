//
//  ControlsView 2.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//


import SwiftUI

struct ControlsView: View {
    @State private var pumpOn = true

    var body: some View {
        VStack(spacing: 20) {
            Toggle("Air Pump", isOn: $pumpOn)

            Button("Calibrate Sensor") {
                print("Calibrating...")
            }
        }
        .padding()
    }
}