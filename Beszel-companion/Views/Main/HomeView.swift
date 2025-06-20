//
//  HomeView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 21/06/2025.
//


// Fichier: Views/HomeView.swift
import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    // Reçoit les données depuis MainView
    let containerData: [ProcessedContainerData]
    let systemDataPoints: [SystemDataPoint]

    var body: some View {
        NavigationView {
            ScrollView {
                if dashboardManager.pinnedItems.isEmpty {
                    Text("Épinglez vos graphiques préférés depuis les pages Conteneurs et Système pour les voir ici.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 20) {
                        ForEach(dashboardManager.pinnedItems) { item in
                            pinnedItemView(for: item)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Accueil")
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch settingsManager.selectedTimeRange {
        case .lastHour, .last12Hours, .last24Hours:
            return .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
        case .last7Days, .last30Days:
            return .dateTime.day(.twoDigits).month(.twoDigits)
        }
    }
    
    // Cette vue "switch" sur le type d'épingle et affiche le bon graphique
    @ViewBuilder
    private func pinnedItemView(for item: PinnedItem) -> some View {
        switch item {
        case .systemCPU:
            GroupBox("CPU système (%)") {
                Chart(systemDataPoints) { point in
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
        case .systemMemory:
            GroupBox("Mémoire système (%)") {
                Chart(systemDataPoints) { point in
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
        case .systemTemperature:
            GroupBox("Températures système (°C)") {
                Chart(systemDataPoints) { point in
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
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.name == name }) {
                GroupBox("CPU: \(name) (%)") {
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
                    .frame(height: 200)
                }
            }
        case .containerMemory(name: let name):
            if let container = containerData.first(where: {$0.name == name}) {
                GroupBox("Utilisation Mémoire: \(name) (Mo)") {
                    Chart(container.statPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Mémoire", point.memory)
                        )
                        .foregroundStyle(.green)
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
    }
}
