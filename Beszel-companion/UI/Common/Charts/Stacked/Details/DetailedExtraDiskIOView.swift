import SwiftUI
import Charts

struct DetailedExtraDiskIOView: View {
    let diskName: String
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    let systemID: String?

    @Environment(DashboardManager.self) var dashboardManager

    private func isPinned(_ item: PinnedItem) -> Bool {
        guard let id = systemID else { return false }
        return dashboardManager.isPinned(item, onSystem: id)
    }

    private func togglePin(_ item: PinnedItem) {
        guard let id = systemID else { return }
        dashboardManager.togglePin(for: item, onSystem: id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ExtraDiskIOChartView(
                    diskName: diskName,
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.extraDiskIO(name: diskName)),
                    onPinToggle: { togglePin(.extraDiskIO(name: diskName)) }
                )

                ExtraDiskIOUtilizationChartView(
                    diskName: diskName,
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.extraDiskIOUtilization(name: diskName)),
                    onPinToggle: { togglePin(.extraDiskIOUtilization(name: diskName)) }
                )
                ExtraDiskIOTimesChartView(
                    diskName: diskName,
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.extraDiskIOTimes(name: diskName)),
                    onPinToggle: { togglePin(.extraDiskIOTimes(name: diskName)) }
                )
                ExtraDiskAwaitChartView(
                    diskName: diskName,
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.extraDiskAwait(name: diskName)),
                    onPinToggle: { togglePin(.extraDiskAwait(name: diskName)) }
                )

                ExtraDiskIOQueueDepthChartView(
                    diskName: diskName,
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.extraDiskIOQueueDepth(name: diskName)),
                    onPinToggle: { togglePin(.extraDiskIOQueueDepth(name: diskName)) }
                )
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
        }
        .navigationTitle(Text("\(diskName) \(LocalizedStringResource("details.extraDiskIO.title"))"))
    }
}
