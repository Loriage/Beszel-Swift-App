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
    let settingsManager: SettingsManager
    let processedData: [ProcessedContainerData]
    let systemID: String?
    var systemName: String? = nil

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
        NavigationLink(destination: DetailedMemoryChartView(
            stackedData: stackedMemory,
            domain: memoryDomainValue,
            uniqueDates: uniqueMemoryDates,
            memoryUnit: memoryUnit,
            memoryLabelScale: memoryLabelScale,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            settingsManager: settingsManager
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("charts.stacked_memory.title \(memoryUnit)")
                        .font(.headline)
                    if let systemName = systemName {
                        Text(systemName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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
                    .drawingGroup()
                }
                .commonChartCustomization(xAxisFormat: xAxisFormat)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
