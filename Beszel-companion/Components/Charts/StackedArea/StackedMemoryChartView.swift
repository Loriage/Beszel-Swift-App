import SwiftUI
import Charts

struct AggregatedMemoryData: Identifiable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let memory: Double
}

struct StackedMemoryData: Identifiable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}

struct StackedMemoryChartView: View {
    @ObservedObject var settingsManager: SettingsManager
    let processedData: [ProcessedContainerData]

    func memoryDomain() -> [String] {
        let averageUsage = processedData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.memory }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        return averageUsage.sorted { $0.avg < $1.avg }.map { $0.name }
    }

    private func stackedData(
        valueExtractor: (AggregatedMemoryData) -> Double,
        domain: [String]
    ) -> [StackedMemoryData] {
        let allPoints = processedData.flatMap { container in
            container.statPoints.map { point in
                AggregatedMemoryData(date: point.date, name: container.name, memory: point.memory)
            }
        }

        guard !allPoints.isEmpty else { return [] }

        let uniqueDates = Set(allPoints.map { $0.date }).sorted()
        let uniqueNames = Set(allPoints.map { $0.name })
        let pointDict = Dictionary(grouping: allPoints, by: { $0.date })

        var stacked: [StackedMemoryData] = []

        for date in uniqueDates {
            var pointsForDate = pointDict[date] ?? []
            let namesWithData = Set(pointsForDate.map { $0.name })

            let missingNames = uniqueNames.subtracting(namesWithData)
            for name in missingNames {
                pointsForDate.append(AggregatedMemoryData(date: date, name: name, memory: 0))
            }

            pointsForDate.sort { domain.firstIndex(of: $0.name)! < domain.firstIndex(of: $1.name)! }

            var cumulative = 0.0
            for point in pointsForDate {
                let value = valueExtractor(point)
                let yStart = cumulative
                let yEnd = cumulative + value
                stacked.append(StackedMemoryData(date: date, name: point.name, yStart: yStart, yEnd: yEnd))
                cumulative = yEnd
            }
        }
        return stacked
    }

    private var memoryDomainValue: [String] { memoryDomain() }
    private var stackedMemory: [StackedMemoryData] { stackedData(valueExtractor: { $0.memory }, domain: memoryDomainValue) }
    private var uniqueMemoryDates: [Date] { Array(Set(stackedMemory.map { $0.date })).sorted() }

    private var maxMemory: Double {
        stackedMemory.max(by: { $0.yEnd < $1.yEnd })?.yEnd ?? 0
    }

    var memoryUnit: String {
        maxMemory >= 1024 ? "GB" : "MB"
    }

    var memoryLabelScale: Double {
        maxMemory >= 1024 ? 1024 : 1
    }

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        NavigationLink(destination: DetailedMemoryChartView(stackedData: stackedMemory, domain: memoryDomainValue, uniqueDates: uniqueMemoryDates, memoryUnit: memoryUnit, memoryLabelScale: memoryLabelScale, xAxisFormat: xAxisFormat, settingsManager: settingsManager)) {
            GroupBox(label: HStack {
                Text("charts.stacked_memory.title \(memoryUnit)")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }) {
                ZStack {
                    Chart(stackedMemory) { data in
                        AreaMark(
                            x: .value("Date", data.date),
                            yStart: .value("Start", data.yStart),
                            yEnd: .value("End", data.yEnd)
                        )
                        .foregroundStyle(by: .value("Conteneur", data.name))
                        .interpolationMethod(.monotone)
                    }
                    .chartForegroundStyleScale(domain: memoryDomainValue, range: gradientRange(for: memoryDomainValue))
                    .chartYAxis {
                        AxisMarks { value in
                            if let yValue = value.as(Double.self) {
                                let scaledValue = yValue / memoryLabelScale
                                let labelText = String(format: "%.1f", scaledValue)
                                AxisGridLine()
                                AxisValueLabel {
                                    Text(labelText)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .commonChartCustomization(xAxisFormat: xAxisFormat)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MemoryChartSectionView: View {
    let stackedData: [StackedMemoryData]
    let domain: [String]
    let uniqueDates: [Date]
    let labelScale: Double
    let xAxisFormat: Date.FormatStyle
    @ObservedObject var settingsManager: SettingsManager

    @Binding var snappedDate: Date?
    @Binding var dragLocation: CGPoint?

    init(stackedData: [StackedMemoryData], domain: [String], uniqueDates: [Date], labelScale: Double = 1.0, xAxisFormat: Date.FormatStyle, settingsManager: SettingsManager, snappedDate: Binding<Date?>, dragLocation: Binding<CGPoint?>) {
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
