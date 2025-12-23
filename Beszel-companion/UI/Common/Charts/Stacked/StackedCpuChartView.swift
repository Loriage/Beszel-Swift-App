import SwiftUI
import Charts

struct StackedCpuChartView: View {
    let stackedData: [StackedCpuData]
    let domain: [String]
    
    @Environment(SettingsManager.self) var settingsManager
    
    let systemID: String?
    var systemName: String? = nil
    
    private var uniqueDates: [Date] {
        Array(Set(stackedData.map { $0.date })).sorted()
    }
    
    var body: some View {
        NavigationLink(destination: DetailedCpuChartView(
            stackedData: stackedData,
            domain: domain,
            uniqueDates: uniqueDates,
            xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat,
            systemID: systemID,
            settingsManager: settingsManager
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("charts.stacked_cpu.title")
                        .font(.headline)
                    if let systemName = systemName {
                        Text(systemName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }) {
                ZStack {
                    Chart(stackedData) { data in
                        AreaMark(
                            x: .value("Date", data.date),
                            yStart: .value("Start", data.yStart),
                            yEnd: .value("End", data.yEnd)
                        )
                        .foregroundStyle(by: .value("Conteneur", data.name))
                        .interpolationMethod(.monotone)
                    }
                    .chartForegroundStyleScale(domain: domain, range: gradientRange(for: domain))
                    .padding(.top, 5)
                    .drawingGroup()
                }
                .commonChartCustomization(xAxisFormat: settingsManager.selectedTimeRange.xAxisFormat)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
