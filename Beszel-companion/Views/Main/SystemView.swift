//
//  SystemView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI
import Charts

struct SystemView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    @Binding var dataPoints: [SystemDataPoint]
    var fetchData: () async -> Void

    private var xAxisFormat: Date.FormatStyle {
        switch settingsManager.selectedTimeRange {
        case .lastHour, .last12Hours, .last24Hours:
            return .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
        case .last7Days, .last30Days:
            return .dateTime.day(.twoDigits).month(.twoDigits)
        }
    }

    var body: some View {
        NavigationView {
            if dataPoints.isEmpty {
                ProgressView("Chargement des données système...")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        cpuChart
                        memoryChart
                        temperatureChart
                    }
                    .padding()
                }
                .navigationTitle("Système")
                .refreshable {
                    await fetchData()
                }
            }
        }
    }

    private var cpuChart: some View {
        GroupBox(label:
            HStack {
                Text("Utilisation CPU (%)")
                Spacer()
                PinButtonView(item: .systemCPU)
            }
        ) {
            Chart(dataPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("CPU", point.cpu))
                    .foregroundStyle(.blue)
                AreaMark(x: .value("Date", point.date), y: .value("CPU", point.cpu))
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYScale(domain: 0...100) // On garde notre échelle fixe
            .frame(height: 200)
        }
    }
    
    private var memoryChart: some View {
        GroupBox(label:
            HStack {
                Text("Utilisation Mémoire (%)")
                Spacer()
                PinButtonView(item: .systemMemory)
            }
        ) {
            Chart(dataPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Mémoire", point.memoryPercent))
                    .foregroundStyle(.green)
                AreaMark(x: .value("Date", point.date), y: .value("Mémoire", point.memoryPercent))
                    .foregroundStyle(LinearGradient(colors: [.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartYScale(domain: 0...100) // On garde notre échelle fixe
            .frame(height: 200)
        }
    }
    
    private var temperatureChart: some View {
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
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .frame(height: 200)
        }
    }
}
