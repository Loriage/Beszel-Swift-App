import SwiftUI
import Charts

struct NetworkMonitorChartView: View {
    let history: NetworkMonitorChartData
    let metric: NetworkMonitorMetric
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned = false
    var onPinToggle: () -> Void = {}
    @Environment(\.chartXDomain) private var xDomain
    @Environment(\.chartShowXGridLines) private var showGrid
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasData: Bool {
        history.samples.contains { metric == .latency ? $0.average != nil : $0.loss != nil }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if hasData {
                    plot.frame(height: 190)
                    if dynamicTypeSize.isAccessibilitySize, let xDomain {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(xDomain.lowerBound, format: xAxisFormat)
                            Text(xDomain.upperBound, format: xAxisFormat)
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                    if metric == .latency {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 14) { legend }
                            VStack(alignment: .leading, spacing: 6) { legend }
                        }
                        .font(.caption2)
                    }
                    let value = metric == .latency ? history.averageLatency : history.packetLoss
                    LabeledContent("monitor.periodAverage", value: value.map { formatted($0) } ?? "—")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("monitor.history.empty")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 190)
                }
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title).font(.headline)
                    Text(verbatim: history.monitor.targetLabel).font(.caption).foregroundStyle(.secondary)
                    if let systemName { Text(verbatim: systemName).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                Button(action: onPinToggle) {
                    Image(systemName: isPinned ? "pin.fill" : "pin").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
                .accessibilityLabel(isPinned ? Text("chart.sensor.unpin") : Text("chart.sensor.pin"))
                .accessibilityValue(isPinned ? Text("chart.sensor.pinned") : Text("chart.sensor.notPinned"))
                .accessibilityIdentifier("pin-\(metric.pinnedItem(id: history.monitor.id).id)")
            }
        }
    }

    @ViewBuilder private var legend: some View {
        MonitorLegendItem(title: "monitor.average", color: .blue, dashed: false)
        MonitorLegendItem(title: "monitor.minimum", color: .green, dashed: true)
        MonitorLegendItem(title: "monitor.maximum", color: .orange, dashed: true)
    }

    private var plot: some View {
        Chart {
            ForEach(history.samples) { sample in
                if metric == .latency {
                    if let value = sample.minimum {
                        LineMark(x: .value("Date", sample.date), y: .value("Min", value), series: .value("Series", "min-\(sample.segment)"))
                            .foregroundStyle(.green).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3])).interpolationMethod(.linear)
                    }
                    if let value = sample.maximum {
                        LineMark(x: .value("Date", sample.date), y: .value("Max", value), series: .value("Series", "max-\(sample.segment)"))
                            .foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3])).interpolationMethod(.linear)
                    }
                    if let value = sample.average {
                        LineMark(x: .value("Date", sample.date), y: .value("Average", value), series: .value("Series", "avg-\(sample.segment)"))
                            .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.linear)
                        PointMark(x: .value("Date", sample.date), y: .value("Average", value)).foregroundStyle(.blue).symbolSize(8)
                    }
                } else if let loss = sample.loss {
                    LineMark(x: .value("Date", sample.date), y: .value("Loss", loss), series: .value("Series", sample.lossSegment))
                        .foregroundStyle(.orange).interpolationMethod(.linear)
                    PointMark(x: .value("Date", sample.date), y: .value("Loss", loss)).foregroundStyle(.orange).symbolSize(8)
                }
            }
        }
        .chartYScale(domain: metric == .loss ? 0...100 : 0...max(1, (history.samples.compactMap(\.maximum).max() ?? 1) * 1.1))
        .chartXScaleIfNeeded(xDomain)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: insetTickDates(for: xDomain, count: dynamicTypeSize.isAccessibilitySize ? 2 : 3)) { _ in
                if showGrid { AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3])) }
                if !dynamicTypeSize.isAccessibilitySize { AxisValueLabel(format: xAxisFormat).font(.caption2) }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 3 : 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) { Text(formatted(number)).font(.caption2) }
                }
            }
        }
        .padding(.top, 5)
        .accessibilityLabel(Text(metric.title))
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(0...2))) + " " + metric.unit
    }
}

private struct MonitorLegendItem: View {
    let title: LocalizedStringResource
    let color: Color
    let dashed: Bool

    var body: some View {
        HStack(spacing: 5) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: 24, y: 3))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
            .frame(width: 24, height: 6)
            .accessibilityHidden(true)
            Text(title).foregroundStyle(.secondary)
        }
    }
}
