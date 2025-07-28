import SwiftUI
import Charts

struct DetailedMemoryChartView: View {
    let stackedData: [StackedMemoryData]
    let domain: [String]
    let uniqueDates: [Date]
    let memoryUnit: String
    let memoryLabelScale: Double
    let xAxisFormat: Date.FormatStyle
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.locale) private var locale

    @State private var snappedDate: Date?
    @State private var dragLocation: CGPoint?

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
                MemoryChartSectionView(
                    stackedData: stackedData,
                    domain: domain,
                    uniqueDates: uniqueDates,
                    labelScale: memoryLabelScale,
                    xAxisFormat: xAxisFormat,
                    settingsManager: settingsManager,
                    snappedDate: $snappedDate,
                    dragLocation: $dragLocation
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

                MemoryDetailedValuesSectionView(
                    values: valuesForDate(snappedDate),
                    sortedDomain: sortedDomain,
                    domain: domain,
                    unit: memoryUnit,
                    settingsManager: settingsManager
                )
            }
            .padding()
        }
        .navigationTitle(Text("details.memory.title \(memoryUnit)"))
    }
}

struct MemoryDetailedValuesSectionView: View {
    let values: [String: Double]
    let sortedDomain: [String]
    let domain: [String]
    let unit: String
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("details.chart.total")
                Text(formatMemory(value: values.values.reduce(0, +), fromUnit: unit))
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
                    Text(formatMemory(value: value, fromUnit: unit))
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
