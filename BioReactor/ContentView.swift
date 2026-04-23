//
//  ContentView.swift
//  BioReactor
//
//  Created by Vidhi Challani on 3/22/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PhotobioreactorViewModel()

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "leaf.fill")
                }

            ControlsView(viewModel: viewModel)
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }

            DeviceView(viewModel: viewModel)
                .tabItem {
                    Label("Device", systemImage: "antenna.radiowaves.left.and.right")
                }

            GasHistoryCardView(history: viewModel.airQualityHistory)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
