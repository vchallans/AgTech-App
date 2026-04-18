import SwiftUI

struct DeviceView: View {
    @ObservedObject var viewModel: PhotobioreactorViewModel

    private var statusColor: Color {
        if viewModel.isConnected {
            return .green
        }

        if viewModel.isScanningForDevice {
            return .orange
        }

        return .blue
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Device Status")
                .font(.title)

            Text(viewModel.bluetoothStatusMessage)
                .foregroundColor(statusColor)
                .multilineTextAlignment(.center)

            Text(viewModel.isConnected ? "Live sensor data over BLE" : "Using simulated readings until a device connects")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let discoveredDeviceName = viewModel.discoveredDeviceName {
                Text("Device: \(discoveredDeviceName)")
                    .font(.subheadline)
            }

            Button(viewModel.isScanningForDevice ? "Scanning..." : "Scan for Device") {
                viewModel.scanForDevice()
            }
            .disabled(viewModel.isScanningForDevice)
        }
        .padding()
    }
}
//  DeviceView.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//
