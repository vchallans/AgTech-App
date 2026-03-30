import SwiftUI

struct DeviceView: View {
    @ObservedObject var viewModel: PhotobioreactorViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Device Status")
                .font(.title)

            Text(viewModel.isConnected ? "Connected" : "Simulation Mode")
                .foregroundColor(viewModel.isConnected ? .green : .blue)

            Button("Scan for Device") {
                print("BLE will go here later")
            }
        }
        .padding()
    }
}
//  DeviceView.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//

