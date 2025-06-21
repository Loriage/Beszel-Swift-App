//
//  SystemCpuChartView 2.swift
//  Beszel
//
//  Created by Bruno DURAND on 21/06/2025.
//

import SwiftUI
import Charts

struct SystemMemoryChartView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    let dataPoints: [SystemDataPoint]

    var body: some View {
        
        GroupBox(label:
            HStack {
                Text("Utilisation Mémoire (%)")
                Spacer()
                PinButtonView(item: .systemMemory)
            }
        ) {
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Mémoire", point.memoryPercent)
                )
                .foregroundStyle(.green)
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Mémoire", point.memoryPercent)
                )
                .foregroundStyle(LinearGradient(colors: [.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: settingsManager.selectedTimeRange.xAxisFormat, centered: true)
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 200)
        }
    }
}
