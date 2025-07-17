import SwiftUI
import Charts

struct AggregatedContainerData: Identifiable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let cpu: Double
    let memory: Double
}

struct StackedContainerData: Identifiable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}

struct StackedContainerChartView: View {
    @ObservedObject var settingsManager: SettingsManager
    let processedData: [ProcessedContainerData]

    private let chartColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .yellow, .pink, .cyan, .indigo, .mint, .teal, .primary, .secondary, .gray,
        Color(red: 0.5, green: 0.0, blue: 0.5), Color(red: 0.0, green: 0.5, blue: 0.5),
        Color(red: 1.0, green: 0.5, blue: 0.0), Color(red: 0.0, green: 0.5, blue: 0.0),
        Color(red: 0.5, green: 0.35, blue: 0.05), Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 0.75, green: 0.75, blue: 0.75), Color(red: 0.0, green: 0.0, blue: 0.5),
        Color(red: 0.87, green: 0.63, blue: 0.87), Color(red: 0.96, green: 0.5, blue: 0.26),
        Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.53, green: 0.81, blue: 0.92),
        Color(red: 0.94, green: 0.9, blue: 0.55), Color(red: 1.0, green: 0.41, blue: 0.71),
        Color(red: 0.3, green: 0.3, blue: 0.3), Color(red: 0.18, green: 0.55, blue: 0.34)
    ]

    private func color(for containerName: String) -> Color {
        var hash = 0
        for char in containerName.unicodeScalars {
            hash = (hash &* 31 &+ Int(char.value))
        }
        let index = abs(hash % chartColors.count)
        return chartColors[index]
    }
    
    private func cpuDomain() -> [String] {
        let averageUsage = processedData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.cpu }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }

        return averageUsage.sorted { $0.avg < $1.avg }.map { $0.name }
    }
        
    private func memoryDomain() -> [String] {
        let averageUsage = processedData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.memory }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }

        return averageUsage.sorted { $0.avg < $1.avg }.map { $0.name }
    }

    private func colorRange(for domain: [String]) -> [Color] {
        return domain.map { color(for: $0) }
    }

    private func gradientRange(for domain: [String]) -> [LinearGradient] {
        return domain.map {
            let baseColor = color(for: $0)
            return LinearGradient(
                colors: [baseColor.opacity(1), baseColor.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func stackedData(
        valueExtractor: (AggregatedContainerData) -> Double,
        domain: [String]
    ) -> [StackedContainerData] {
        let allPoints = processedData.flatMap { container in
            container.statPoints.map { point in
                AggregatedContainerData(date: point.date, name: container.name, cpu: point.cpu, memory: point.memory)
            }
        }
        
        guard !allPoints.isEmpty else { return [] }
        
        let uniqueDates = Set(allPoints.map { $0.date }).sorted()
        let uniqueNames = Set(allPoints.map { $0.name })
        let pointDict = Dictionary(grouping: allPoints, by: { $0.date })
        
        var stacked: [StackedContainerData] = []
        
        for date in uniqueDates {
            var pointsForDate = pointDict[date] ?? []
            let namesWithData = Set(pointsForDate.map { $0.name })

            let missingNames = uniqueNames.subtracting(namesWithData)
            for name in missingNames {
                pointsForDate.append(AggregatedContainerData(date: date, name: name, cpu: 0, memory: 0))
            }

            pointsForDate.sort { domain.firstIndex(of: $0.name)! < domain.firstIndex(of: $1.name)! }

            var cumulative = 0.0
            for point in pointsForDate {
                let value = valueExtractor(point)
                let yStart = cumulative
                let yEnd = cumulative + value
                stacked.append(StackedContainerData(date: date, name: point.name, yStart: yStart, yEnd: yEnd))
                cumulative = yEnd
            }
        }
        
        return stacked
    }
    
    private var stackedCpuData: [StackedContainerData] {
        let domain = cpuDomain()
        return stackedData(valueExtractor: { $0.cpu }, domain: domain)
    }
    
    private var stackedMemoryData: [StackedContainerData] {
        let domain = memoryDomain()
        return stackedData(valueExtractor: { $0.memory }, domain: domain)
    }

    private var maxMemory: Double {
        stackedMemoryData.max(by: { $0.yEnd < $1.yEnd })?.yEnd ?? 0
    }

    private var memoryUnit: String {
        maxMemory >= 1024 ? "Go" : "Mo"
    }

    private var memoryLabelScale: Double {
        maxMemory >= 1024 ? 1024 : 1
    }

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            GroupBox(label: Text("Utilisation CPU totale des conteneurs (%)").font(.headline)) {
                let domain = self.cpuDomain()

                ZStack {
                    Chart(stackedCpuData) { data in
                        AreaMark(
                            x: .value("Date", data.date),
                            yStart: .value("Start", data.yStart),
                            yEnd: .value("End", data.yEnd)
                        )
                        .foregroundStyle(by: .value("Conteneur", data.name))
                        .interpolationMethod(.monotone)
                    }
                    .chartForegroundStyleScale(domain: domain, range: gradientRange(for: domain))
                }
                .commonChartCustomization()
            }

            GroupBox(label: Text("Utilisation Mémoire totale des conteneurs (\(memoryUnit))").font(.headline)) {
                let domain = self.memoryDomain()

                ZStack {
                    Chart(stackedMemoryData) { data in
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
                                let scaledValue = yValue / memoryLabelScale
                                let labelText = String(format: "%.1f", scaledValue)
                                AxisValueLabel {
                                    Text(labelText)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .commonChartCustomization()
            }
        }
        .padding(.horizontal)
    }
}

private extension View {
    func commonChartCustomization() -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute(), centered: true)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 250)
    }
}
