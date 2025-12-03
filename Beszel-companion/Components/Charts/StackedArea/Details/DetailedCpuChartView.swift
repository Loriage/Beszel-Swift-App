import SwiftUI
import Charts
import Observation

struct DetailedCpuChartView: View {
    let stackedData: [StackedCpuData]
    let domain: [String]
    let uniqueDates: [Date]
    let xAxisFormat: Date.FormatStyle
    let systemID: String?
    
    // Changement : let pour settingsManager, @Environment pour dashboardManager
    let settingsManager: SettingsManager
    @Environment(DashboardManager.self) var dashboardManager
    
    @Environment(\.locale) private var locale

    @State private var snappedDate: Date?
    @State private var dragLocation: CGPoint?

    private var isPinned: Bool {
        guard let systemID = systemID else { return false }
        return dashboardManager.isPinned(.stackedContainerCPU, onSystem: systemID)
    }

    private func togglePin() {
        guard let systemID = systemID else { return }
        dashboardManager.togglePin(for: .stackedContainerCPU, onSystem: systemID)
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
                CpuChartSectionView(
                    stackedData: stackedData,
                    domain: domain,
                    uniqueDates: uniqueDates,
                    labelScale: scale,
                    xAxisFormat: xAxisFormat,
                    settingsManager: settingsManager,
                    snappedDate: $snappedDate,
                    dragLocation: $dragLocation,
                    isPinned: isPinned,
                    onPinToggle: togglePin
                )

                if let date = snappedDate {
                    let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
                    let localizedStyle = style.locale(locale)

                    Text("details.chart.values_at_date \(date.formatted(localizedStyle))")
                        .font(.headline)
                } else {
                    Text("details.chart.drag_prompt")
                        .font(.headline)
                }

                CpuDetailedValuesSectionView(
                    values: valuesForDate(snappedDate),
                    sortedDomain: sortedDomain,
                    domain: domain,
                    unit: unit,
                    valueFormatString: "%.1f%@",
                    settingsManager: settingsManager
                )
            }
            .padding()
        }
        .navigationTitle(Text("details.cpu.title"))
    }
}

struct CpuDetailedValuesSectionView: View {
    let values: [String: Double]
    let sortedDomain: [String]
    let domain: [String]
    let unit: String
    let valueFormatString: String
    let settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("details.chart.total")
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

struct CpuChartSectionView: View {
    let stackedData: [StackedCpuData]
    let domain: [String]
    let uniqueDates: [Date]
    let labelScale: Double
    let xAxisFormat: Date.FormatStyle
    let settingsManager: SettingsManager

    @Binding var snappedDate: Date?
    @Binding var dragLocation: CGPoint?

    var isPinned: Bool
    var onPinToggle: () -> Void

    init(stackedData: [StackedCpuData], domain: [String], uniqueDates: [Date], labelScale: Double = 1.0, xAxisFormat: Date.FormatStyle, settingsManager: SettingsManager, snappedDate: Binding<Date?>, dragLocation: Binding<CGPoint?>, isPinned: Bool, onPinToggle: @escaping () -> Void) {
        self.stackedData = stackedData
        self.domain = domain
        self.uniqueDates = uniqueDates
        self.labelScale = labelScale
        self.xAxisFormat = xAxisFormat
        self.settingsManager = settingsManager
        self._snappedDate = snappedDate
        self._dragLocation = dragLocation
        self.isPinned = isPinned
        self.onPinToggle = onPinToggle
    }

    var body: some View {
        GroupBox(label: HStack {
            Text("details.cpu.title")
                .font(.headline)
            Spacer()
            PinButtonView(isPinned: isPinned, action: onPinToggle)
        }) {
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
            .drawingGroup()
            .commonChartCustomization(xAxisFormat: xAxisFormat)
        }
    }
}
