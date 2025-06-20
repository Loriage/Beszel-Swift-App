//
//  MainView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI

struct MainView: View {
    @StateObject var apiService: BeszelAPIService
    @EnvironmentObject var settingsManager: SettingsManager
    
    var onLogout: () -> Void

    @State private var containerData: [ProcessedContainerData] = []
    @State private var systemDataPoints: [SystemDataPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        TabView {
            // --- Onglet 1 : Accueil ---
            HomeView(
                containerData: containerData,
                systemDataPoints: systemDataPoints
            )
            .tabItem {
                Label("Accueil", systemImage: "house.fill")
            }

            // --- Onglet 2 : Conteneurs ---
            ContainerView(
                processedData: $containerData, // On passe une liaison (Binding)
                fetchData: fetchData // On passe la fonction de rechargement
            )
            .tabItem {
                Label("Conteneurs", systemImage: "shippingbox.fill")
            }

            // --- Onglet 3 : Système ---
            SystemView(
                dataPoints: $systemDataPoints, // On passe une liaison (Binding)
                fetchData: fetchData // On passe la fonction de rechargement
            )
            .tabItem {
                Label("Système", systemImage: "cpu.fill")
            }

            // --- Onglet 4 : Paramètres ---
            SettingsView(onLogout: onLogout)
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
        }
        .task { await fetchData() }
        .onChange(of: settingsManager.selectedTimeRange) {
            Task { await fetchData() }
        }
    }

    // La fonction de récupération est maintenant centralisée ici
    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        let filter = settingsManager.apiFilterString
        
        do {
            // On utilise un TaskGroup pour lancer les deux appels en parallèle
            async let containerRecords = apiService.fetchMonitors(filter: filter)
            async let systemRecords = apiService.fetchSystemStats(filter: filter)
            
            // On transforme les résultats
            self.containerData = transform(records: try await containerRecords)
            self.systemDataPoints = transformSystem(records: try await systemRecords)
            
        } catch {
            self.errorMessage = error.localizedDescription
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
    private func transformSystem(records: [SystemStatsRecord]) -> [SystemDataPoint] {
        // On utilise compactMap pour ignorer les enregistrements dont la date serait invalide
        let dataPoints = records.compactMap { record -> SystemDataPoint? in
            // On utilise notre formateur de date personnalisé pour parser la date
            guard let date = DateFormatter.pocketBase.date(from: record.created) else {
                // Si la date est invalide, on ignore cet enregistrement
                return nil
            }
            
            // On transforme le dictionnaire de températures en un tableau de tuples
            // pour qu'il soit plus facile à utiliser avec Swift Charts.
            let tempsArray = record.stats.temperatures.map { (name: $0.key, value: $0.value) }
            
            // On crée et on retourne notre objet optimisé pour les graphiques
            return SystemDataPoint(
                date: date,
                cpu: record.stats.cpu,
                memoryPercent: record.stats.memoryPercent,
                temperatures: tempsArray
            )
        }
        
        // On s'assure que les points sont bien triés par date avant de les renvoyer
        return dataPoints.sorted(by: { $0.date < $1.date })
    }
}
