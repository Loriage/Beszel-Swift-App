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
            case .lastHour, .last12Hours, .last24Hours:
                return .dateTime.hour().minute()
            case .last7Days, .last30Days:
                return .dateTime.day(.twoDigits).month(.twoDigits)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ContainerCpuChartView(container: container)
                ContainerMemoryChartView(container: container)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(container.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
