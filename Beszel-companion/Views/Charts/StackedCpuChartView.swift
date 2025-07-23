import SwiftUI
import Charts

struct AggregatedCpuData: Identifiable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let cpu: Double
}

struct StackedCpuData: Identifiable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}

struct StackedCpuChartView: View {
    @ObservedObject var settingsManager: SettingsManager
    let processedData: [ProcessedContainerData]

    func cpuDomain() -> [String] {
        let averageUsage = processedData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.cpu }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        return averageUsage.sorted { $0.avg < $1.avg }.map { $0.name }
    }

    private func stackedData(
        valueExtractor: (AggregatedCpuData) -> Double,
        domain: [String]
    ) -> [StackedCpuData] {
        let allPoints = processedData.flatMap { container in
            container.statPoints.map { point in
                AggregatedCpuData(date: point.date, name: container.name, cpu: point.cpu)
            }
        }

        guard !allPoints.isEmpty else { return [] }

        let uniqueDates = Set(allPoints.map { $0.date }).sorted()
        let uniqueNames = Set(allPoints.map { $0.name })
        let pointDict = Dictionary(grouping: allPoints, by: { $0.date })

        var stacked: [StackedCpuData] = []

        for date in uniqueDates {
            var pointsForDate = pointDict[date] ?? []
            let namesWithData = Set(pointsForDate.map { $0.name })

            let missingNames = uniqueNames.subtracting(namesWithData)
            for name in missingNames {
                pointsForDate.append(AggregatedCpuData(date: date, name: name, cpu: 0))
            }

            pointsForDate.sort { domain.firstIndex(of: $0.name)! < domain.firstIndex(of: $1.name)! }

            var cumulative = 0.0
            for point in pointsForDate {
                let value = valueExtractor(point)
                let yStart = cumulative
                let yEnd = cumulative + value
                stacked.append(StackedCpuData(date: date, name: point.name, yStart: yStart, yEnd: yEnd))
                cumulative = yEnd
            }
        }
        return stacked
    }

    private var cpuDomainValue: [String] { cpuDomain() }
    private var stackedCpu: [StackedCpuData] { stackedData(valueExtractor: { $0.cpu }, domain: cpuDomainValue) }
    private var uniqueCpuDates: [Date] { Array(Set(stackedCpu.map { $0.date })).sorted() }

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        NavigationLink(destination: DetailedCpuChartView(stackedData: stackedCpu, domain: cpuDomainValue, uniqueDates: uniqueCpuDates, xAxisFormat: xAxisFormat, settingsManager: settingsManager)) {
            GroupBox(label: HStack {
                Text("Utilisation CPU totale des conteneurs (%)")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }) {
                ZStack {
                    Chart(stackedCpu) { data in
                        AreaMark(
                            x: .value("Date", data.date),
                            yStart: .value("Start", data.yStart),
                            yEnd: .value("End", data.yEnd)
                        )
                        .foregroundStyle(by: .value("Conteneur", data.name))
                        .interpolationMethod(.monotone)
                    }
                    .chartForegroundStyleScale(domain: cpuDomainValue, range: gradientRange(for: cpuDomainValue))
                }
                .commonChartCustomization(xAxisFormat: xAxisFormat)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CpuChartSectionView: View {
    let stackedData: [StackedCpuData]
    let domain: [String]
    let uniqueDates: [Date]
    let labelScale: Double
    let xAxisFormat: Date.FormatStyle
    @ObservedObject var settingsManager: SettingsManager

    @Binding var snappedDate: Date?
    @Binding var dragLocation: CGPoint?

    init(stackedData: [StackedCpuData], domain: [String], uniqueDates: [Date], labelScale: Double = 1.0, xAxisFormat: Date.FormatStyle, settingsManager: SettingsManager, snappedDate: Binding<Date?>, dragLocation: Binding<CGPoint?>) {
        self.stackedData = stackedData
        self.domain = domain
        self.uniqueDates = uniqueDates
        self.labelScale = labelScale
        self.xAxisFormat = xAxisFormat
        self.settingsManager = settingsManager
        self._snappedDate = snappedDate
        self._dragLocation = dragLocation
    }

    var body: some View {
        GroupBox {
            Chart(stackedData) { data in
                AreaMark(
                    x: .value("Date", data.date),
                    yStart: .value("Start", data.yStart),
                    yEnd: .value("End", data.yEnd)
                )
                .foregroundStyle(by: .value("Conteneur", data.name))
                .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(domain: domain, range: gradientRange(for: domain))
            .chartYAxis {
                AxisMarks { value in
                    if let yValue = value.as(Double.self) {
                        let scaledValue = yValue / labelScale
                        let labelText = String(format: "%.1f", scaledValue)
                        AxisGridLine()
                        AxisValueLabel {
                            Text(labelText)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        if let snappedDate = snappedDate {
                            let xPosition = proxy.position(forX: snappedDate) ?? 0
                            Path { path in
                                path.move(to: CGPoint(x: xPosition, y: 0))
                                path.addLine(to: CGPoint(x: xPosition, y: geometry.size.height))
                            }
                            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        }

                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragLocation = value.location
                                        if let date = proxy.value(atX: value.location.x, as: Date.self) {
                                            snappedDate = uniqueDates.min(by: { abs($0.timeIntervalSince(date)) < abs($1.timeIntervalSince(date)) })
                                        }
                                    }
                                    .onEnded { _ in
                                        dragLocation = nil
                                    }
                            )
                    }
                }
            }
            .commonChartCustomization(xAxisFormat: xAxisFormat)
        }
    }
}

struct CpuDetailedValuesSectionView: View {
    let values: [String: Double]
    let sortedDomain: [String]
    let domain: [String]
    let unit: String
    let valueFormatString: String
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Total : ")
                Text(String(format: valueFormatString, values.values.reduce(0, +), unit))
            }
            .font(.title3)
            .bold()
            .padding(.vertical, 12)
            .padding(.horizontal)

            Divider()
                .padding(.horizontal, 16)

            ForEach(Array(sortedDomain.enumerated()), id: \.element) { index, name in
                HStack {
                    Circle().fill(color(for: name, in: domain)).frame(width: 10, height: 10)
                    Text(name)
                    Spacer()
                    let value = values[name] ?? 0.0
                    Text(String(format: valueFormatString, value, unit))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)

                if index < sortedDomain.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
