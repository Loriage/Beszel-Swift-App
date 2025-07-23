/*
import SwiftUI
import Charts

enum ChartType {
    case cpu
    case memory
}

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
        .blue,
        .green,
        .red,
        .orange,
        .purple,
        .yellow,
        .pink,
        .cyan,
        .indigo,
        .mint,
        .teal,
        Color(hue: 0.00, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.04, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.08, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.12, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.16, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.20, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.24, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.28, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.32, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.36, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.40, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.44, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.48, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.52, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.56, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.60, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.64, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.68, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.72, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.76, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.80, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.84, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.88, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.92, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.96, saturation: 0.70, brightness: 0.85)
    ]

    public func color(for containerName: String) -> Color {
        var hash = 0
        for char in containerName.unicodeScalars {
            hash = (hash &* 31 &+ Int(char.value))
        }
        let index = abs(hash % chartColors.count)
        return chartColors[index]
    }

    func cpuDomain() -> [String] {
        let averageUsage = processedData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.cpu }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        return averageUsage.sorted { $0.avg < $1.avg }.map { $0.name }
    }

    func memoryDomain() -> [String] {
        let averageUsage = processedData.map { container -> (name: String, avg: Double) in
            let total = container.statPoints.reduce(0) { $0 + $1.memory }
            let average = container.statPoints.isEmpty ? 0 : total / Double(container.statPoints.count)
            return (name: container.name, avg: average)
        }
        return averageUsage.sorted { $0.avg < $1.avg }.map { $0.name }
    }

    public func gradientRange(for domain: [String]) -> [LinearGradient] {
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

    private var cpuDomainValue: [String] { cpuDomain() }
    private var memoryDomainValue: [String] { memoryDomain() }
    private var stackedCpu: [StackedContainerData] { stackedData(valueExtractor: { $0.cpu }, domain: cpuDomainValue) }
    private var stackedMemory: [StackedContainerData] { stackedData(valueExtractor: { $0.memory }, domain: memoryDomainValue) }
    private var uniqueCpuDates: [Date] { Array(Set(stackedCpu.map { $0.date })).sorted() }
    private var uniqueMemoryDates: [Date] { Array(Set(stackedMemory.map { $0.date })).sorted() }

    private var maxMemory: Double {
        stackedMemory.max(by: { $0.yEnd < $1.yEnd })?.yEnd ?? 0
    }

    var memoryUnit: String {
        maxMemory >= 1024 ? "Go" : "Mo"
    }

    var memoryLabelScale: Double {
        maxMemory >= 1024 ? 1024 : 1
    }

    private var xAxisFormat: Date.FormatStyle {
        settingsManager.selectedTimeRange.xAxisFormat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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

            NavigationLink(destination: DetailedMemoryChartView(stackedData: stackedMemory, domain: memoryDomainValue, uniqueDates: uniqueMemoryDates, memoryUnit: memoryUnit, memoryLabelScale: memoryLabelScale, xAxisFormat: xAxisFormat, settingsManager: settingsManager)) {
                GroupBox(label: HStack {
                    Text("Utilisation Mémoire totale des conteneurs (\(memoryUnit))")
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
        .padding(.horizontal)
    }
}

struct ChartSectionView: View {
    let stackedData: [StackedContainerData]
    let domain: [String]
    let uniqueDates: [Date]
    let memoryLabelScale: Double
    let xAxisFormat: Date.FormatStyle
    @ObservedObject var settingsManager: SettingsManager

    @Binding var snappedDate: Date?
    @Binding var dragLocation: CGPoint?

    init(stackedData: [StackedContainerData], domain: [String], uniqueDates: [Date], memoryLabelScale: Double = 1.0, xAxisFormat: Date.FormatStyle, settingsManager: SettingsManager, snappedDate: Binding<Date?>, dragLocation: Binding<CGPoint?>) {
        self.stackedData = stackedData
        self.domain = domain
        self.uniqueDates = uniqueDates
        self.memoryLabelScale = memoryLabelScale
        self.xAxisFormat = xAxisFormat
        self._settingsManager = ObservedObject(wrappedValue: settingsManager)
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
            .chartForegroundStyleScale(domain: domain, range: StackedContainerChartView(settingsManager: settingsManager, processedData: []).gradientRange(for: domain))
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

struct DetailedValuesSectionView: View {
    let values: [String: Double]
    let sortedDomain: [String]
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
                    Circle().fill(StackedContainerChartView(settingsManager: settingsManager, processedData: []).color(for: name)).frame(width: 10, height: 10)
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

struct DetailedCpuChartView: View {
    let stackedData: [StackedContainerData]
    let domain: [String]
    let uniqueDates: [Date]
    let xAxisFormat: Date.FormatStyle
    @ObservedObject var settingsManager: SettingsManager

    @State private var snappedDate: Date?
    @State private var dragLocation: CGPoint?

    private var title: String {
        "Détails Utilisation CPU (%)"
    }

    private var unit: String {
        "%"
    }

    private var scale: Double {
        1.0
    }

    private func valuesForDate(_ date: Date?) -> [String: Double] {
        guard let date = date else { return [:] }
        let pointsForDate = stackedData.filter { $0.date == date }
        if pointsForDate.isEmpty { return [:] }
        var dict: [String: Double] = [:]
        for point in pointsForDate {
            let value = (point.yEnd - point.yStart) / scale
            if dict[point.name] != nil {
                print("Debug: Duplicate key '\(point.name)' found, keeping first value")
            } else {
                dict[point.name] = value
            }
        }
        return dict
    }

    private var sortedDomain: [String] {
        let values = valuesForDate(snappedDate)
        return domain.sorted { (values[$0] ?? 0) > (values[$1] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ChartSectionView(
                    stackedData: stackedData,
                    domain: domain,
                    uniqueDates: uniqueDates,
                    memoryLabelScale: scale,
                    xAxisFormat: xAxisFormat,
                    settingsManager: settingsManager,
                    snappedDate: $snappedDate,
                    dragLocation: $dragLocation
                )

                Text(snappedDate != nil ? "Valeurs le \(snappedDate!.formatted(date: .abbreviated, time: .shortened))" : "Faites glisser sur l'axe X pour sélectionner une date.")
                    .font(.headline)

                DetailedValuesSectionView(
                    values: valuesForDate(snappedDate),
                    sortedDomain: sortedDomain,
                    unit: unit,
                    valueFormatString: "%.1f%@",
                    settingsManager: settingsManager
                )
            }
            .padding()
        }
        .navigationTitle(title)
    }
}

struct DetailedMemoryChartView: View {
    let stackedData: [StackedContainerData]
    let domain: [String]
    let uniqueDates: [Date]
    let memoryUnit: String
    let memoryLabelScale: Double
    let xAxisFormat: Date.FormatStyle
    @ObservedObject var settingsManager: SettingsManager

    @State private var snappedDate: Date?
    @State private var dragLocation: CGPoint?

    private var title: String {
        "Détails Utilisation Mémoire (\(memoryUnit))"
    }

    private var unit: String {
        memoryUnit
    }

    private var scale: Double {
        memoryLabelScale
    }

    private func valuesForDate(_ date: Date?) -> [String: Double] {
        guard let date = date else { return [:] }
        let pointsForDate = stackedData.filter { $0.date == date }
        if pointsForDate.isEmpty { return [:] }
        var dict: [String: Double] = [:]
        for point in pointsForDate {
            let value = (point.yEnd - point.yStart) / scale
            if dict[point.name] != nil {
                print("Debug: Duplicate key '\(point.name)' found, keeping first value")
            } else {
                dict[point.name] = value
            }
        }
        return dict
    }

    private var sortedDomain: [String] {
        let values = valuesForDate(snappedDate)
        return domain.sorted { (values[$0] ?? 0) > (values[$1] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ChartSectionView(
                    stackedData: stackedData,
                    domain: domain,
                    uniqueDates: uniqueDates,
                    memoryLabelScale: memoryLabelScale,
                    xAxisFormat: xAxisFormat,
                    settingsManager: settingsManager,
                    snappedDate: $snappedDate,
                    dragLocation: $dragLocation
                )

                Text(snappedDate != nil ? "Valeurs le \(snappedDate!.formatted(date: .abbreviated, time: .shortened))" : "Faites glisser sur l'axe X pour sélectionner une date.")
                    .font(.headline)

                DetailedValuesSectionView(
                    values: valuesForDate(snappedDate),
                    sortedDomain: sortedDomain,
                    unit: unit,
                    valueFormatString: "%.1f %@",
                    settingsManager: settingsManager
                )
            }
            .padding()
        }
        .navigationTitle(title)
    }
}

private extension View {
    func commonChartCustomization(xAxisFormat: Date.FormatStyle) -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 250)
    }
}
*/
