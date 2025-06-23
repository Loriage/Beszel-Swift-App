import SwiftUI

struct ContainerView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    @Binding var processedData: [ProcessedContainerData]

    var fetchData: () async -> Void
    @Binding var isShowingSettings: Bool

    var body: some View {
        NavigationView {
            List(processedData.sorted(by: { $0.name < $1.name })) { container in
                VStack(alignment: .leading) {
                    NavigationLink(destination: ContainerDetailView(container: container, settingsManager: settingsManager)) {
                        Text(container.name)
                    }
                }
            }
            .navigationTitle("Conteneurs")
            .navigationSubtitle("Liste des conteneurs Dockers")
            .refreshable {
                await fetchData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {isShowingSettings = true}) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }
}
