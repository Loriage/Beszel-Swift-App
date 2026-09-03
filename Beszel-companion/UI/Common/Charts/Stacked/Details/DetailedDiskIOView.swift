import SwiftUI
import Charts

struct DetailedDiskIOView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    let systemID: String?
    var xDomain: ClosedRange<Date>? = nil
    var diskName: String? = nil

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
                if let diskName, !diskName.isEmpty {
                    Text(verbatim: diskName).font(.title2.bold())
                }
                // Throughput (read/write bytes/s)
                SystemDiskIOChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    diskName: diskName,
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

                if dataPoints.contains(where: { $0.diskIOTotals != nil }) {
                    StorageHistoryChart(metric: .cumulativeRead(disk: nil), dataPoints: dataPoints, xAxisFormat: xAxisFormat)
                    StorageHistoryChart(metric: .cumulativeWrite(disk: nil), dataPoints: dataPoints, xAxisFormat: xAxisFormat)
                }
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
        }
        .environment(\.chartXDomain, xDomain)
        .monitoringScreenBackground()
        .navigationTitle(Text("details.diskIO.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
