import SwiftUI
import Charts

struct SystemView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    @Binding var dataPoints: [SystemDataPoint]
    var fetchData: () async -> Void
    var onShowSettings: () -> Void

    var body: some View {
        NavigationView {
            if dataPoints.isEmpty {
                ProgressView("Chargement des données système...")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SystemCpuChartView(dataPoints: dataPoints)
                        SystemMemoryChartView(dataPoints: dataPoints)
                        SystemTemperatureChartView(dataPoints: dataPoints)
                    }
                    .padding(.horizontal)
                }
                .navigationTitle("Système")
                .navigationSubtitle("Utilisation moyenne à l'échelle du système")
                .refreshable {
                    await fetchData()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onShowSettings) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }
        }
    }
}
