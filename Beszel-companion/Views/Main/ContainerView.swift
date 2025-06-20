//
//  ContainerView.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import SwiftUI

struct ContainerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    @Binding var processedData: [ProcessedContainerData]
    
    var fetchData: () async -> Void

    var body: some View {
        NavigationView {
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
}
