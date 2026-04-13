import SwiftUI
import Charts

struct DetailedBandwidthView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    let systemID: String?
    var xDomain: ClosedRange<Date>? = nil

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
                BandwidthDownloadChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemBandwidthDownload),
                    onPinToggle: { togglePin(.systemBandwidthDownload) }
                )
                BandwidthUploadChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemBandwidthUpload),
                    onPinToggle: { togglePin(.systemBandwidthUpload) }
                )
                BandwidthCumulativeDownloadChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemBandwidthCumulativeDownload),
                    onPinToggle: { togglePin(.systemBandwidthCumulativeDownload) }
                )
                BandwidthCumulativeUploadChartView(
                    dataPoints: dataPoints,
                    xAxisFormat: xAxisFormat,
                    isPinned: isPinned(.systemBandwidthCumulativeUpload),
                    onPinToggle: { togglePin(.systemBandwidthCumulativeUpload) }
                )
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
        }
        .environment(\.chartXDomain, xDomain)
        .navigationTitle(Text("details.bandwidth.title"))
    }
}
