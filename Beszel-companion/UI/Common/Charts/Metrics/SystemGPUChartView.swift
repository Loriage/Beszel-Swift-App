import SwiftUI
import Charts

struct SystemGPUChartView: View {
    let history: GPUChartData
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned = false
    var onPinToggle: () -> Void = {}

    var body: some View {
        GroupBox {
            GPUChartContent(history: history, xAxisFormat: xAxisFormat)
        } label: {
            HStack(alignment: .top) {
                GPUChartHeading(history: history, systemName: systemName)
                Spacer(minLength: 8)
                Button(action: onPinToggle) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(isPinned ? Text("chart.sensor.unpin") : Text("chart.sensor.pin"))
                .accessibilityValue(isPinned ? Text("chart.sensor.pinned") : Text("chart.sensor.notPinned"))
                .accessibilityIdentifier("pin-\(history.metric.pinnedItem(deviceID: history.device?.id).id)")
            }
        }
    }
}

struct SystemGPUSummaryChartView: View {
    let charts: SystemGPUCharts
    let xAxisFormat: Date.FormatStyle
    let systemID: String?
    let instanceID: String?
    var systemName: String? = nil
    @Environment(\.chartXDomain) private var xDomain
    @Environment(\.chartShowXGridLines) private var showGrid

    var body: some View {
        NavigationLink {
            SystemGPUDetailView(charts: charts, xAxisFormat: xAxisFormat, systemID: systemID, instanceID: instanceID)
                .environment(\.chartXDomain, xDomain)
                .environment(\.chartShowXGridLines, showGrid)
        } label: {
            GroupBox {
                GPUChartContent(history: charts.usage, xAxisFormat: xAxisFormat)
            } label: {
                HStack {
                    GPUChartHeading(history: charts.usage, systemName: systemName)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("gpu-details")
    }
}

struct SystemGPUDetailView: View {
    let charts: SystemGPUCharts
    let xAxisFormat: Date.FormatStyle
    let systemID: String?
    let instanceID: String?
    @Environment(DashboardManager.self) private var dashboardManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if charts.usage.hasReadings { chart(charts.usage) }
                if charts.power.hasReadings { chart(charts.power) }
                ForEach(charts.memory, id: \.device?.id) { chart($0) }
                ForEach(charts.engines, id: \.device?.id) { chart($0) }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
        .monitoringScreenBackground()
        .navigationTitle("chart.gpu.details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chart(_ history: GPUChartData) -> some View {
        let item = history.metric.pinnedItem(deviceID: history.device?.id)
        return SystemGPUChartView(
            history: history, xAxisFormat: xAxisFormat,
            isPinned: {
                guard let systemID, let instanceID else { return false }
                return dashboardManager.isPinned(item, onSystem: systemID, inInstance: instanceID)
            }(),
            onPinToggle: {
                if let systemID, let instanceID {
                    dashboardManager.togglePin(for: item, onSystem: systemID, inInstance: instanceID)
                }
            }
        )
    }
}

private struct GPUChartHeading: View {
    let history: GPUChartData
    let systemName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text(history.metric.title) + Text(" (\(history.metric.unit))"))
                .font(.headline)
            if let device = history.device {
                Text(verbatim: device.name).font(.caption2).foregroundStyle(.secondary)
            }
            if let systemName {
                Text(verbatim: systemName).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(history.metric.subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct GPUChartContent: View {
    let history: GPUChartData
    let xAxisFormat: Date.FormatStyle
    @Environment(\.chartXDomain) private var xDomain
    @Environment(\.chartShowXGridLines) private var showGrid
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 8) {
            if !history.hasReadings {
                Text("widget.noData").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                plot.frame(height: 190)
                if dynamicTypeSize.isAccessibilitySize, let xDomain {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(xDomain.lowerBound, format: xAxisFormat).fixedSize()
                            Spacer()
                            Text(xDomain.upperBound, format: xAxisFormat).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(xDomain.lowerBound, format: xAxisFormat)
                            Text(xDomain.upperBound, format: xAxisFormat)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(history.series) { series in
                            HStack(spacing: 4) {
                                if series.isReference {
                                    Image(systemName: "line.diagonal").foregroundStyle(seriesColor(series))
                                } else {
                                    Circle().fill(seriesColor(series)).frame(width: 8, height: 8)
                                }
                                Text(verbatim: series.name).foregroundStyle(.secondary)
                            }
                            .font(.caption2)
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(series.currentValue.map { history.metric.formatted($0, locale: locale) } ?? "—")
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(minHeight: 20)
            }
        }
    }

    private var plot: some View {
        Chart {
            ForEach(history.series) { series in
                ForEach(series.samples) { sample in
                    LineMark(
                        x: .value("Date", sample.date), y: .value("Value", sample.value),
                        series: .value("GPU", "\(series.id)-\(sample.segment)")
                    )
                    .foregroundStyle(seriesColor(series))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: series.isReference ? [5, 3] : []))
                    .interpolationMethod(.linear)
                }
                if series.samples.count == 1, let sample = series.samples.first {
                    PointMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                        .foregroundStyle(seriesColor(series))
                }
            }
        }
        .chartYScale(domain: history.yDomain)
        .chartXScaleIfNeeded(xDomain)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: insetTickDates(for: xDomain, count: dynamicTypeSize.isAccessibilitySize ? 2 : 4)) { _ in
                if showGrid {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    AxisTick()
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    AxisValueLabel(format: xAxisFormat).font(.caption2)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number, format: .number.notation(.compactName).precision(.fractionLength(0...1)))
                            .font(.caption2).padding(.trailing, 6)
                    }
                }
            }
        }
        .padding(.top, 5)
        .accessibilityHidden(true)
    }

    private func seriesColor(_ series: GPUChartSeries) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        return palette[series.styleIndex % palette.count].opacity(series.isReference ? 0.65 : 1)
    }
}
