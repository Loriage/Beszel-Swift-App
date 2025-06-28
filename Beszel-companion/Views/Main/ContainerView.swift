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

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(processedData.sorted(by: { $0.name < $1.name })) { container in
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
                            Divider()
                            .padding(.leading)
                        }
                    }
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
