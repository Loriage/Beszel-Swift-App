import SwiftUI

struct ContainerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    @Binding var processedData: [ProcessedContainerData]
    
    var fetchData: () async -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("container.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("container.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                if !processedData.isEmpty {
                    StackedContainerChartView(
                        settingsManager: settingsManager,
                        processedData: processedData
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        let sortedData = processedData.sorted(by: { $0.name < $1.name })
                        ForEach(Array(sortedData.enumerated()), id: \.element.id) { index, container in
                            NavigationLink(destination: ContainerDetailView(container: container, settingsManager: settingsManager)) {
                                HStack {
                                    Text(container.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }

                            if index < sortedData.count - 1 {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding()
            }
        }
        .refreshable {
            await fetchData()
        }
    }
}
