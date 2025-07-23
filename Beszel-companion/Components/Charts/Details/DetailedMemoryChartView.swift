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

                Text(snappedDate != nil ? "Valeurs le \(snappedDate!.formatted(date: .abbreviated, time: .shortened))" : "Faites glisser sur l'axe X pour sélectionner une date.")
                    .font(.headline)

                MemoryDetailedValuesSectionView(
                    values: valuesForDate(snappedDate),
                    sortedDomain: sortedDomain,
                    domain: domain,
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
