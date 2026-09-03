import Charts
import SwiftUI

/// Storage metrics keep their native units: ZFS capacity is GiB, I/O is bytes/s,
/// and cumulative counters are bytes since boot (never an integral of sampled rates).
enum StorageHistoryMetric: Equatable {
    case poolUsage(String)
    case poolIO(String)
    case cumulativeRead(disk: String?)
    case cumulativeWrite(disk: String?)

    var title: LocalizedStringResource {
        switch self {
        case .poolUsage: "zfs.usage"
        case .poolIO: "zfs.io"
        case .cumulativeRead: "chart.disk.cumulativeRead"
        case .cumulativeWrite: "chart.disk.cumulativeWrite"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .poolUsage: "zfs.usage.subtitle"
        case .poolIO: "zfs.io.subtitle"
        case .cumulativeRead: "chart.disk.cumulativeRead.subtitle"
        case .cumulativeWrite: "chart.disk.cumulativeWrite.subtitle"
        }
    }

    var hasWriteSeries: Bool {
        if case .poolIO = self { return true }
        return false
    }

    func value(in point: SystemDataPoint, write: Bool = false) -> Double? {
        switch self {
        case .poolUsage(let name): point.zfsPools[name]?.du
        case .poolIO(let name): point.zfsPools[name].map { write ? ($0.wb ?? 0) : ($0.rb ?? 0) }
        case .cumulativeRead(let disk):
            if let disk { point.extraFilesystems.first { $0.name == disk }?.totalRead }
            else { point.diskIOTotals?.read }
        case .cumulativeWrite(let disk):
            if let disk { point.extraFilesystems.first { $0.name == disk }?.totalWrite }
            else { point.diskIOTotals?.write }
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .poolUsage: StorageValueFormatter.bytes(value * 1_073_741_824)
        case .poolIO: MetricFormatter.throughput(bytesPerSecond: value)
        case .cumulativeRead, .cumulativeWrite: StorageValueFormatter.bytes(value)
        }
    }
}

struct StorageHistoryChart: View {
    let metric: StorageHistoryMetric
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    @Environment(\.chartXDomain) private var chartXDomain
    @Environment(\.chartShowXGridLines) private var showGrid
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GroupBox {
            Chart(dataPoints) { point in
                if let value = metric.value(in: point) {
                    LineMark(x: .value("Date", point.date), y: .value("Value", value), series: .value("Series", "Read"))
                        .foregroundStyle(.blue)
                }
                if metric.hasWriteSeries, let value = metric.value(in: point, write: true) {
                    LineMark(x: .value("Date", point.date), y: .value("Value", value), series: .value("Series", "Write"))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
            }
            .chartXScaleIfNeeded(chartXDomain)
            .chartXAxis {
                AxisMarks(values: insetTickDates(for: chartXDomain, count: dynamicTypeSize.isAccessibilitySize ? 2 : 4)) { _ in
                    if showGrid { AxisGridLine() }
                    if !dynamicTypeSize.isAccessibilitySize {
                        AxisValueLabel(format: xAxisFormat).font(.caption2)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 3 : 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(metric.formatted(number)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 190)
            .accessibilityLabel(Text(metric.title))
            .accessibilityValue(latestValue)

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

            if metric.hasWriteSeries {
                HStack(spacing: 16) {
                    StorageLegendItem(title: "chart.diskIO.read", color: .blue, dashed: false)
                    StorageLegendItem(title: "chart.diskIO.write", color: .orange, dashed: true)
                }
                .padding(.top, 4)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title).font(.headline)
                Text(metric.subtitle).font(.caption).foregroundStyle(.secondary)
                if !latestValue.isEmpty {
                    Text(latestValue).font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private var latestValue: String {
        guard let point = dataPoints.last, let value = metric.value(in: point) else { return "" }
        if metric.hasWriteSeries, let write = metric.value(in: point, write: true) {
            return "\(String(localized: "chart.diskIO.read")): \(metric.formatted(value)) · \(String(localized: "chart.diskIO.write")): \(metric.formatted(write))"
        }
        return metric.formatted(value)
    }
}

private struct StorageLegendItem: View {
    let title: LocalizedStringResource
    let color: Color
    let dashed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: 28, y: 3))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [5, 3] : []))
            .frame(width: 28, height: 6)
            .accessibilityHidden(true)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

enum StorageValueFormatter {
    static func bytes(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        let bytes = value >= Double(Int64.max) ? Int64.max : Int64(value.rounded(.down))
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    static func bytes(_ value: UInt64?) -> String {
        value.map { bytes(Double($0)) } ?? "—"
    }
}
