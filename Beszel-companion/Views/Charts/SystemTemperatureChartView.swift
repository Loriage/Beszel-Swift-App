//
//  SystemCpuChartView 2.swift
//  Beszel
//
//  Created by Bruno DURAND on 21/06/2025.
//

import SwiftUI
import Charts

struct SystemTemperatureChartView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    let dataPoints: [SystemDataPoint]

    var body: some View {
        
        GroupBox(label:
            HStack {
                Text("Températures (°C)")
                Spacer()
                PinButtonView(item: .systemTemperature)
            }
        ) {
            Chart(dataPoints) { point in
                ForEach(point.temperatures, id: \.name) { temp in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Temp", temp.value)
                    )
                    .foregroundStyle(by: .value("Source", temp.name))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: settingsManager.selectedTimeRange.xAxisFormat, centered: true)
                }
            }
            .frame(height: 200)
        }
    }
}
