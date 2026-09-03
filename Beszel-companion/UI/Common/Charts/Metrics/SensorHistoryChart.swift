import Charts
import SwiftUI

struct SensorHistoryChart: View {
    let history: SensorChartData
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned = false
    var onPinToggle: () -> Void = {}

    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GroupBox {
            if history.series.isEmpty {
                Text("widget.noData")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                SensorHistoryPlot(history: history, xAxisFormat: xAxisFormat)
                    .frame(height: 190)
                if dynamicTypeSize.isAccessibilitySize, let domain = chartXDomain {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text(domain.lowerBound, format: xAxisFormat).fixedSize()
                            Spacer()
                            Text(domain.upperBound, format: xAxisFormat).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(domain.lowerBound, format: xAxisFormat)
                            Text(domain.upperBound, format: xAxisFormat)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                SensorHistoryLegend(series: history.series, metric: history.metric)
                .padding(.top, 8)
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.metric.title).font(.headline)
                    Text(history.metric.subtitle).font(.caption).foregroundStyle(.secondary)
                    if let systemName {
                        Text(verbatim: systemName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Button(action: onPinToggle) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(isPinned ? Text("chart.sensor.unpin") : Text("chart.sensor.pin"))
                .accessibilityValue(isPinned ? Text("chart.sensor.pinned") : Text("chart.sensor.notPinned"))
                .accessibilityIdentifier("pin-\(history.metric.pinnedItem.id)")
            }
        }
    }
}

private struct SensorHistoryPlot: View {
    let history: SensorChartData
    let xAxisFormat: Date.FormatStyle
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var showGrid
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Chart {
            ForEach(history.series) { series in
                ForEach(series.samples) { sample in
                    LineMark(
                        x: .value("Date", sample.date), y: .value("Value", sample.value),
                        series: .value("Sensor", "\(series.id)-\(sample.segment)")
                    )
                    .foregroundStyle(SensorHistoryStyle.color(series.styleIndex))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    // Sensor readings stay inside their physical bounds between samples.
                    .interpolationMethod(.linear)
                }
                if let sample = series.samples.last {
                    PointMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                        .foregroundStyle(SensorHistoryStyle.color(series.styleIndex))
                        .symbolSize(16)
                }
            }
        }
        .chartYScale(domain: history.yDomain)
        .chartXScaleIfNeeded(chartXDomain)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: insetTickDates(for: chartXDomain, count: dynamicTypeSize.isAccessibilitySize ? 2 : 4)) { _ in
                if showGrid { AxisGridLine() }
                if !dynamicTypeSize.isAccessibilitySize {
                    AxisValueLabel(format: xAxisFormat).font(.caption2)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number, format: .number.notation(.compactName).precision(.fractionLength(0...1)))
                            .font(.caption2)
                    }
                }
            }
        }
        .accessibilityHidden(true) // Equivalent, labeled values are in the legend below.
    }
}

/// Matches the horizontal dot-and-label legends used by Temperature, GPU and Network Interfaces.
private struct SensorHistoryLegend: View {
    let series: [SensorChartSeries]
    let metric: SensorHistoryMetric

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(series) { series in
                    SensorHistoryLegendItem(series: series, metric: metric)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(minHeight: 20)
        .accessibilityIdentifier("sensor-legend-\(metric.pinnedItem.id)")
    }
}

private struct SensorHistoryLegendItem: View {
    let series: SensorChartSeries
    let metric: SensorHistoryMetric
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(SensorHistoryStyle.color(series.styleIndex))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            if let name = series.name {
                Text(name)
            } else {
                Text("chart.battery.charge")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityValue(series.currentValue.map { metric.formatted($0, locale: locale) } ?? "—")
    }
}

private enum SensorHistoryStyle {
    static func color(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        return palette[index % palette.count]
    }

}
