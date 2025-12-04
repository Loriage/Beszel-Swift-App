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
    let settingsManager: SettingsManager
    let processedData: [ProcessedContainerData]
    let systemID: String?
    var systemName: String? = nil

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
        NavigationLink(destination: DetailedCpuChartView(
            stackedData: stackedCpu,
            domain: cpuDomainValue,
            uniqueDates: uniqueCpuDates,
            xAxisFormat: xAxisFormat,
            systemID: systemID,
            settingsManager: settingsManager
        )) {
            GroupBox(label: HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("charts.stacked_cpu.title")
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
                    .padding(.top, 5)
                    .drawingGroup()
                }
                .commonChartCustomization(xAxisFormat: xAxisFormat)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
