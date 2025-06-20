//
//  ContainerView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI

struct ContainerView: View {
    @StateObject var apiService: BeszelAPIService
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var processedData: [ProcessedContainerData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading && processedData.isEmpty {
                    ProgressView("Analyse des données...")
                } else if let errorMessage = errorMessage {
                    Text("Erreur : \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List(processedData.sorted(by: { $0.name < $1.name })) { container in
                        NavigationLink(destination: ContainerDetailView(container: container, settingsManager: settingsManager)) {
                            Text(container.name)
                        }
                    }
                    .navigationTitle("Conteneurs")
                    .refreshable {
                        await fetchData()
                    }
                }
            }
            .task {
                await fetchData()
            }
            .onChange(of: settingsManager.selectedTimeRange) {
                Task { await fetchData() }
            }
        }
    }

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            let filter = settingsManager.apiFilterString
            let records = try await apiService.fetchMonitors(filter: filter)
            
            processedData = transform(records: records)

        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func transform(records: [ContainerStatsRecord]) -> [ProcessedContainerData] {
        var containerDict = [String: [StatPoint]]()

        for record in records {
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                continue
            }

            for stat in record.stats {
                let point = StatPoint(date: date, cpu: stat.cpu, memory: stat.memory)
                containerDict[stat.name, default: []].append(point)
            }
        }
        
        let result = containerDict.map { name, points in
            ProcessedContainerData(id: name, statPoints: points.sorted(by: { $0.date < $1.date }))
        }
        
        return result
    }
}
