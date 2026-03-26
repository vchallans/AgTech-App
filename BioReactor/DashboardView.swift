import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Photobioreactor")
                .font(.largeTitle.bold())

            Text("CO₂: 650 ppm")
            Text("Temp: 24°C")
            Text("Humidity: 52%")

            Text("Algae Health: Good")
                .foregroundColor(.green)
        }
        .padding()
    }
}