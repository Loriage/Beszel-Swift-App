import SwiftUI
import Charts

private struct InterfaceSample: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let value: Double
}

private func formatAdaptiveBytes(_ bytes: Double, divisor: Double) -> String {
    let v = bytes / divisor
    return v.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", v) : String(format: "%.1f", v)
}

private func adaptiveUnit(for maxBytes: Double) -> (label: String, divisor: Double) {
    if maxBytes >= 1_073_741_824 { return ("GB/s", 1_073_741_824) }
    if maxBytes >= 1_048_576     { return ("MB/s", 1_048_576) }
    if maxBytes >= 1024          { return ("KB/s", 1024) }
    return ("B/s", 1)
}

private func adaptiveCumulativeUnit(for maxBytes: Double) -> (label: String, divisor: Double) {
    if maxBytes >= 1_099_511_627_776 { return ("TB", 1_099_511_627_776) }
    if maxBytes >= 1_073_741_824     { return ("GB", 1_073_741_824) }
    if maxBytes >= 1_048_576         { return ("MB", 1_048_576) }
    if maxBytes >= 1024              { return ("KB", 1024) }
    return ("B", 1)
}

private func cumulativeSamples(
    from dataPoints: [SystemDataPoint],
    total totalKeyPath: KeyPath<NetworkInterfacePoint, Double?>,
    rate rateKeyPath: KeyPath<NetworkInterfacePoint, Double>
) -> [InterfaceSample] {
    let hasActualTotals = dataPoints.contains { point in
        point.networkInterfaces.contains { ($0[keyPath: totalKeyPath] ?? 0) > 0 }
    }

    var result = [InterfaceSample]()

    if hasActualTotals {
        for point in dataPoints {
            for iface in point.networkInterfaces {
                if let total = iface[keyPath: totalKeyPath], total > 0 {
                    result.append(InterfaceSample(date: point.date, name: iface.name, value: total))
                }
            }
        }
    } else {
        var accumulated = [String: Double]()
        var prevDates = [String: Date]()
        for point in dataPoints {
            for iface in point.networkInterfaces {
                let interval = prevDates[iface.name]
                    .map { point.date.timeIntervalSince($0) } ?? 60.0
                let contribution = iface[keyPath: rateKeyPath] * max(interval, 0)
                let cumulative = (accumulated[iface.name] ?? 0) + contribution
                accumulated[iface.name] = cumulative
                prevDates[iface.name] = point.date
                result.append(InterfaceSample(date: point.date, name: iface.name, value: cumulative))
            }
        }
    }
    return result
}

struct BandwidthDownloadChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var interfaceNames: [String] {
        Array(Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) })).sorted()
    }

    private var samples: [InterfaceSample] {
        dataPoints.flatMap { point in
            point.networkInterfaces.map { iface in
                InterfaceSample(date: point.date, name: iface.name, value: iface.received)
            }
        }
    }

    private var maxRate: Double { samples.map(\.value).max() ?? 0 }

    private func baseChart(divisor: Double) -> some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Date", sample.date),
                yStart: .value("", 0),
                yEnd: .value("Rate", sample.value)
            )
            .foregroundStyle(by: .value("Interface", sample.name))
            .opacity(0.25)
            LineMark(
                x: .value("Date", sample.date),
                y: .value("Rate", sample.value)
            )
            .foregroundStyle(by: .value("Interface", sample.name))
        }
        .chartForegroundStyleScale { name in color(for: name, in: interfaceNames) }
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
                        Text(v == 0 ? "0" : formatAdaptiveBytes(v, divisor: divisor)).font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .padding(.top, 5)
        .frame(height: 185)
        .drawingGroup()
    }

    var body: some View {
        let (unit, divisor) = adaptiveUnit(for: maxRate)
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.bandwidth.perInterface.download") + Text(" (\(unit))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.bandwidth.perInterface.download.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                if maxRate == 0 {
                    baseChart(divisor: divisor).chartYScale(domain: 0...1.0)
                } else {
                    baseChart(divisor: divisor)
                }

                if !interfaceNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(interfaceNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: interfaceNames))
                                        .frame(width: 8, height: 8)
                                    Text(name).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

struct BandwidthUploadChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var interfaceNames: [String] {
        Array(Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) })).sorted()
    }

    private var samples: [InterfaceSample] {
        dataPoints.flatMap { point in
            point.networkInterfaces.map { iface in
                InterfaceSample(date: point.date, name: iface.name, value: iface.sent)
            }
        }
    }

    private var maxRate: Double { samples.map(\.value).max() ?? 0 }

    private func baseChart(divisor: Double) -> some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Date", sample.date),
                yStart: .value("", 0),
                yEnd: .value("Rate", sample.value)
            )
            .foregroundStyle(by: .value("Interface", sample.name))
            .opacity(0.25)
            LineMark(
                x: .value("Date", sample.date),
                y: .value("Rate", sample.value)
            )
            .foregroundStyle(by: .value("Interface", sample.name))
        }
        .chartForegroundStyleScale { name in color(for: name, in: interfaceNames) }
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
                        Text(v == 0 ? "0" : formatAdaptiveBytes(v, divisor: divisor)).font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .padding(.top, 5)
        .frame(height: 185)
        .drawingGroup()
    }

    var body: some View {
        let (unit, divisor) = adaptiveUnit(for: maxRate)
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.bandwidth.perInterface.upload") + Text(" (\(unit))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.bandwidth.perInterface.upload.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                if maxRate == 0 {
                    baseChart(divisor: divisor).chartYScale(domain: 0...1.0)
                } else {
                    baseChart(divisor: divisor)
                }

                if !interfaceNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(interfaceNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: interfaceNames))
                                        .frame(width: 8, height: 8)
                                    Text(name).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

struct BandwidthCumulativeDownloadChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var interfaceNames: [String] {
        Array(Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) })).sorted()
    }

    private var samples: [InterfaceSample] {
        cumulativeSamples(from: dataPoints, total: \.totalReceived, rate: \.received)
    }

    private var maxBytes: Double { samples.map(\.value).max() ?? 0 }

    private func baseChart(divisor: Double) -> some View {
        Chart(samples) { sample in
            LineMark(
                x: .value("Date", sample.date),
                y: .value("Value", sample.value)
            )
            .foregroundStyle(by: .value("Interface", sample.name))
        }
        .chartForegroundStyleScale { name in color(for: name, in: interfaceNames) }
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
                        Text(v == 0 ? "0" : formatAdaptiveBytes(v, divisor: divisor)).font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .padding(.top, 5)
        .frame(height: 185)
        .drawingGroup()
    }

    var body: some View {
        let (unit, divisor) = adaptiveCumulativeUnit(for: maxBytes)
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.bandwidth.cumulative.download") + Text(" (\(unit))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.bandwidth.cumulative.download.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                if maxBytes == 0 {
                    baseChart(divisor: divisor).chartYScale(domain: 0...1.0)
                } else {
                    baseChart(divisor: divisor)
                }

                if !interfaceNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(interfaceNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: interfaceNames))
                                        .frame(width: 8, height: 8)
                                    Text(name).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

struct BandwidthCumulativeUploadChartView: View {
    let dataPoints: [SystemDataPoint]
    let xAxisFormat: Date.FormatStyle
    var systemName: String? = nil
    var isPinned: Bool = false
    var onPinToggle: () -> Void = {}

    private var interfaceNames: [String] {
        Array(Set(dataPoints.flatMap { $0.networkInterfaces.map(\.name) })).sorted()
    }

    private var samples: [InterfaceSample] {
        cumulativeSamples(from: dataPoints, total: \.totalSent, rate: \.sent)
    }

    private var maxBytes: Double { samples.map(\.value).max() ?? 0 }

    private func baseChart(divisor: Double) -> some View {
        Chart(samples) { sample in
            LineMark(
                x: .value("Date", sample.date),
                y: .value("Value", sample.value)
            )
            .foregroundStyle(by: .value("Interface", sample.name))
        }
        .chartForegroundStyleScale { name in color(for: name, in: interfaceNames) }
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
                        Text(v == 0 ? "0" : formatAdaptiveBytes(v, divisor: divisor)).font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .padding(.top, 5)
        .frame(height: 185)
        .drawingGroup()
    }

    var body: some View {
        let (unit, divisor) = adaptiveCumulativeUnit(for: maxBytes)
        GroupBox(label: HStack {
            VStack(alignment: .leading, spacing: 2) {
                (Text("chart.bandwidth.cumulative.upload") + Text(" (\(unit))"))
                    .font(.headline)
                if systemName == nil {
                    Text("chart.bandwidth.cumulative.upload.subtitle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let systemName = systemName {
                    Text(systemName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
            VStack(spacing: 4) {
                if maxBytes == 0 {
                    baseChart(divisor: divisor).chartYScale(domain: 0...1.0)
                } else {
                    baseChart(divisor: divisor)
                }

                if !interfaceNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(interfaceNames, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(for: name, in: interfaceNames))
                                        .frame(width: 8, height: 8)
                                    Text(name).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}
