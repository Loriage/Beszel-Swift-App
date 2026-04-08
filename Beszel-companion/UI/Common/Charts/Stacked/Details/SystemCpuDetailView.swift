import SwiftUI
import Charts

private struct SingleCoreSample: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct SystemCpuDetailView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    let systemID: String?
    var xDomain: ClosedRange<Date>? = nil

    @Environment(DashboardManager.self) var dashboardManager

    private var coreNames: [String] {
        guard let first = dataPoints.first, let cores = first.cpuPerCore else { return [] }
        return (0..<cores.count).map { "CPU \($0)" }
    }

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
                SystemMetricChartView(
                    title: "chart.cpuUsage",
                    xAxisFormat: xAxisFormat,
                    dataPoints: dataPoints,
                    valueKeyPath: \.cpu,
                    color: .blue,
                    unit: "%",
                    isPinned: isPinned(.systemCPU),
                    onPinToggle: { togglePin(.systemCPU) }
                )

                if dataPoints.contains(where: { $0.cpuBreakdown != nil }) {
                    SystemCpuTimeBreakdownChartView(
                        dataPoints: dataPoints,
                        xAxisFormat: xAxisFormat,
                        isPinned: isPinned(.systemCPUTimeBreakdown),
                        onPinToggle: { togglePin(.systemCPUTimeBreakdown) }
                    )
                }

                if dataPoints.contains(where: { $0.cpuPerCore != nil }) {
                    SystemCpuCoresChartView(
                        dataPoints: dataPoints,
                        xAxisFormat: xAxisFormat,
                        isPinned: isPinned(.systemCPUCores),
                        onPinToggle: { togglePin(.systemCPUCores) }
                    )

                    ForEach(Array(coreNames.enumerated()), id: \.offset) { index, name in
                        singleCoreChart(index: index, name: name)
                    }
                }
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
        }
        .environment(\.chartXDomain, xDomain)
        .navigationTitle(Text("chart.cpuUsage"))
    }

    private func singleCoreChart(index: Int, name: String) -> some View {
        let names = coreNames
        let coreColor = color(for: name, in: names)
        let samples: [SingleCoreSample] = dataPoints.compactMap { point in
            guard let cores = point.cpuPerCore, index < cores.count else { return nil }
            return SingleCoreSample(date: point.date, value: cores[index])
        }
        let maxVal = samples.map(\.value).max() ?? 0

        return GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text(name) + Text(" (%)"))
                    .font(.headline)
                Text("chart.cpu.cores.subtitle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }) {
            Chart(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("CPU", sample.value)
                )
                .foregroundStyle(coreColor)
                AreaMark(
                    x: .value("Date", sample.date),
                    yStart: .value("", 0),
                    yEnd: .value("CPU", sample.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [coreColor.opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
            .chartYScale(domain: 0...(maxVal > 0 ? min(maxVal * 1.15, 100) : 100))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0f", v)).font(.caption2)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(xDomain)
            .padding(.top, 5)
            .frame(height: 200)
            .drawingGroup()
        }
    }
}
