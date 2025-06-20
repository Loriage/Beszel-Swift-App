//
//  ContainerDetailView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI
import Charts

struct ContainerDetailView: View {
    let container: ProcessedContainerData
    @ObservedObject var settingsManager: SettingsManager
    
    private var xAxisFormat: Date.FormatStyle {
        switch settingsManager.selectedTimeRange {
        case .lastHour, .last12Hours:
            return .dateTime.hour().minute() // Affiche "14:30"
        case .last24Hours, .last7Days:
            return .dateTime.month(.abbreviated).day() // Affiche "20 juin"
        case .last30Days:
            return .dateTime.day().month() // Affiche "20/06"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox("Utilisation CPU (%)") {
                    Chart(container.statPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("CPU", point.cpu)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisValueLabel(format: xAxisFormat, centered: true)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 200)
                }

                GroupBox("Utilisation Mémoire (Mo)") {
                    Chart(container.statPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Mémoire", point.memory)
                        )
                        .foregroundStyle(.green)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5))
                    }
                    .frame(height: 200)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(container.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
