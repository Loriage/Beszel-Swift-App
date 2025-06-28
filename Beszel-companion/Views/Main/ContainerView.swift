import SwiftUI

struct ContainerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    @Binding var processedData: [ProcessedContainerData]
    
    var fetchData: () async -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text("container.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("container.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                List(processedData.sorted(by: { $0.name < $1.name })) { container in
                    VStack(alignment: .leading) {
                        NavigationLink(destination: ContainerDetailView(container: container, settingsManager: settingsManager)) {
                            Text(container.name)
                        }
                    }
                }
                .contentMargins(.top, 18)
                .frame(height: CGFloat((processedData.count * 54) + (processedData.count < 4 ? 200 : 0)), alignment: .top)
            }
        }
        .refreshable {
            await fetchData()
        }
    }
}
