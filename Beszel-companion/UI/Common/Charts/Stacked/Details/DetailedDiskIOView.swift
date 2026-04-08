import SwiftUI
import Charts

struct DetailedDiskIOView: View {
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
                // Throughput (read/write bytes/s)
                SystemDiskIOChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemDiskIO),
                    onPinToggle: { togglePin(.systemDiskIO) }
                )

                SystemDiskIOUtilizationChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemDiskIOUtilization),
                    onPinToggle: { togglePin(.systemDiskIOUtilization) }
                )

                SystemDiskIOTimesChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemDiskIOTimes),
                    onPinToggle: { togglePin(.systemDiskIOTimes) }
                )

                SystemDiskAwaitChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemDiskAwait),
                    onPinToggle: { togglePin(.systemDiskAwait) }
                )

                SystemDiskIOQueueDepthChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemDiskIOQueueDepth),
                    onPinToggle: { togglePin(.systemDiskIOQueueDepth) }
                )
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
        }
        .navigationTitle(Text("details.diskIO.title"))
    }
}
