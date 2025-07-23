import SwiftUI
import Charts

struct HomeView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @EnvironmentObject var dashboardManager: DashboardManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading) {
                    Text("home.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("home.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                if dashboardManager.allPinsForActiveInstance.isEmpty {
                    emptyStateView
                } else {
                    HStack {
                        TextField("dashboard.searchPlaceholder", text: $homeViewModel.searchText)
                            .padding(8)
                            .padding(.leading, 24)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                }
                            )
                        Button(action: {
                            homeViewModel.isShowingFilterSheet = true
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title)
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 24) {
                        ForEach(homeViewModel.filteredAndSortedPins) { resolvedItem in
                            pinnedItemView(for: resolvedItem)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear { homeViewModel.fetchData() }
        .sheet(isPresented: $homeViewModel.isShowingFilterSheet) {
            FilterView(
                sortOption: $homeViewModel.sortOption,
                sortDescending: $homeViewModel.sortDescending
            )
        }
    }

    private var emptyStateView: some View {
        VStack (alignment: .center, spacing: 8) {
            Image(systemName: "pin.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("home.empty.title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
            Text("home.empty.message")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 80)
    }

    @ViewBuilder
    private func pinnedItemView(for resolvedItem: ResolvedPinnedItem) -> some View {
        let systemData = homeViewModel.systemData(for: resolvedItem)
        let containerData = homeViewModel.containerData(for: resolvedItem)
        let systemName = homeViewModel.systemName(for: resolvedItem)
        
        switch resolvedItem.item {
        case .systemCPU:
            SystemCpuChartView(
                xAxisFormat: homeViewModel.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.isPinned(.systemCPU),
                onPinToggle: { homeViewModel.togglePin(for: .systemCPU) }
            )
        case .systemMemory:
            SystemMemoryChartView(
                xAxisFormat: homeViewModel.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.isPinned(.systemMemory),
                onPinToggle: { homeViewModel.togglePin(for: .systemMemory) }
            )
        case .systemTemperature:
            if homeViewModel.hasTemperatureData {
                SystemTemperatureChartView(
                    xAxisFormat: homeViewModel.xAxisFormat,
                    dataPoints: systemData,
                    systemName: systemName,
                    isPinned: homeViewModel.isPinned(.systemTemperature),
                    onPinToggle: { homeViewModel.togglePin(for: .systemTemperature) }
                )
            }
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(
                    xAxisFormat: homeViewModel.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: homeViewModel.isPinned(.containerCPU(name: container.name)),
                    onPinToggle: { homeViewModel.togglePin(for: .containerCPU(name: container.name)) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(
                    xAxisFormat: homeViewModel.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: homeViewModel.isPinned(.containerMemory(name: container.name)),
                    onPinToggle: { homeViewModel.togglePin(for: .containerMemory(name: container.name)) }
                )
            }
        }
    }
}
