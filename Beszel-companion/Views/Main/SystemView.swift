//
//  SystemView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI
import Charts

struct SystemView: View {
    @ObservedObject var apiService: BeszelAPIService
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var dataPoints: [SystemDataPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var xAxisFormat: Date.FormatStyle {
        switch settingsManager.selectedTimeRange {
            case .lastHour, .last12Hours, .last24Hours:
                return .dateTime.hour().minute()
            case .last7Days, .last30Days:
                return .dateTime.day(.twoDigits).month(.twoDigits)
            }
    }

    var body: some View {
        NavigationView {
            if isLoading {
                ProgressView("Chargement des données système...")
            } else if let errorMessage = errorMessage {
                Text("Erreur : \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
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
                .refreshable { await fetchData() }
            }
        }
        .task {
            await fetchData()
        }
        .onChange(of: settingsManager.selectedTimeRange) {
            Task { await fetchData() }
        }
    }

    private var cpuChart: some View {
        GroupBox("Utilisation CPU (%)") {
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
            .frame(height: 200)
        }
    }
    
    private var memoryChart: some View {
        GroupBox("Utilisation Mémoire (%)") {
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
            .frame(height: 200)
        }
    }
    
    private var temperatureChart: some View {
        GroupBox("Températures (°C)") {
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

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let filter = settingsManager.apiFilterString
            let records = try await apiService.fetchSystemStats(filter: filter)
            
            self.dataPoints = records.compactMap { record in
                guard let date = DateFormatter.pocketBase.date(from: record.created) else { return nil }
                let tempsArray = record.stats.temperatures.map { (name: $0.key, value: $0.value) }
                return SystemDataPoint(date: date, cpu: record.stats.cpu, memoryPercent: record.stats.memoryPercent, temperatures: tempsArray)
            }.sorted(by: { $0.date < $1.date })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
