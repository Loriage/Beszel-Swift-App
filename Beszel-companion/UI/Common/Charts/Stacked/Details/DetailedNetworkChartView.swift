import SwiftUI
import Charts
import Observation

struct NetworkValuePair {
    let sent: Double
    let received: Double
    var total: Double { sent + received }
}

struct DetailedNetworkChartView: View {
    let stackedData: [StackedNetworkData]
    let domain: [String]
    let uniqueDates: [Date]
    let networkUnit: String
    let networkLabelScale: Double
    let xAxisFormat: Date.FormatStyle
    let systemID: String?

    let settingsManager: SettingsManager
    @Environment(DashboardManager.self) var dashboardManager
    @Environment(\.locale) private var locale

    @State private var snappedDate: Date?
    @State private var dragLocation: CGPoint?

    private var isPinned: Bool {
        guard let systemID = systemID else { return false }
        return dashboardManager.isPinned(.stackedContainerNetwork, onSystem: systemID)
    }

    private func togglePin() {
        guard let systemID = systemID else { return }
        dashboardManager.togglePin(for: .stackedContainerNetwork, onSystem: systemID)
    }

    private var scale: Double {
        networkLabelScale
    }

    private func valuesForDate(_ date: Date?) -> [String: NetworkValuePair] {
        guard let date = date else { return [:] }
        let pointsForDate = stackedData.filter { $0.date == date }
        if pointsForDate.isEmpty { return [:] }
        var dict: [String: NetworkValuePair] = [:]
        for point in pointsForDate {
            if dict[point.name] == nil {
                dict[point.name] = NetworkValuePair(
                    sent: point.netSent / scale,
                    received: point.netReceived / scale
                )
            }
        }
        return dict
    }

    private var sortedDomain: [String] {
        let values = valuesForDate(snappedDate)
        return domain.sorted { (values[$0]?.total ?? 0) > (values[$1]?.total ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NetworkChartSectionView(
                    stackedData: stackedData,
                    domain: domain,
                    uniqueDates: uniqueDates,
                    labelScale: networkLabelScale,
                    networkUnit: networkUnit,
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

                NetworkDetailedValuesSectionView(
                    values: valuesForDate(snappedDate),
                    sortedDomain: sortedDomain,
                    domain: domain,
                    unit: networkUnit,
                    settingsManager: settingsManager
                )
            }
            .groupBoxStyle(CardGroupBoxStyle())
            .padding()
        }
        .navigationTitle(Text("details.network.title \(networkUnit)"))
    }
}

struct NetworkDetailedValuesSectionView: View {
    let values: [String: NetworkValuePair]
    let sortedDomain: [String]
    let domain: [String]
    let unit: String
    let settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("details.chart.total")
                Text(formatNetworkRate(values.values.reduce(0) { $0 + $1.total }, unit: unit))
            }
            .font(.title3)
            .bold()
            .padding(.vertical, 12)
            .padding(.horizontal)

            Divider()
                .padding(.horizontal, 16)

            ForEach(Array(sortedDomain.enumerated()), id: \.element) { index, name in
                HStack(alignment: .lastTextBaseline) {
                    Circle().fill(color(for: name, in: domain)).frame(width: 10, height: 10)
                    Text(name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(-1)
                    Spacer()
                    if let pair = values[name] {
                        Text("\(formatNetworkRate(pair.received, unit: unit)) rx | \(formatNetworkRate(pair.sent, unit: unit)) tx")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .lineLimit(1)
                            .fixedSize()
                    }
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
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private func formatNetworkRate(_ mbsValue: Double, unit: String) -> String {
    if unit == "MB/s" {
        if mbsValue >= 1 {
            return String(format: "%.2f MB/s", mbsValue)
        }
        return String(format: "%.2f KB/s", mbsValue * 1024)
    } else {
        if mbsValue >= 1024 {
            return String(format: "%.2f MB/s", mbsValue / 1024)
        }
        return String(format: "%.2f KB/s", mbsValue)
    }
}

struct NetworkChartSectionView: View {
    let stackedData: [StackedNetworkData]
    let domain: [String]
    let uniqueDates: [Date]
    let labelScale: Double
    let networkUnit: String
    let xAxisFormat: Date.FormatStyle
    let settingsManager: SettingsManager

    @Binding var snappedDate: Date?
    @Binding var dragLocation: CGPoint?

    var isPinned: Bool
    var onPinToggle: () -> Void

    var body: some View {
        GroupBox(label: HStack {
            Text("details.network.title \(networkUnit)")
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
            .padding(.top, 5)
            .drawingGroup()
            .commonChartCustomization(xAxisFormat: xAxisFormat)
        }
    }
}
