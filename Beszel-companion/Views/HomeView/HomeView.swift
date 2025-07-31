import SwiftUI
import Charts

struct HomeView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @EnvironmentObject var dashboardManager: DashboardManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeaderView(title: "home.title", subtitle: "home.subtitle")

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
        .onAppear { Task { homeViewModel.chartDataManager.fetchData() } }
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
        let systemData = homeViewModel.chartDataManager.systemData(forSystemID: resolvedItem.systemID)
        let containerData = homeViewModel.chartDataManager.containerData(forSystemID: resolvedItem.systemID)
        let systemName = homeViewModel.chartDataManager.systemName(forSystemID: resolvedItem.systemID)

        switch resolvedItem.item {
        case .systemCPU:
            SystemCpuChartView(
                xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.chartDataManager.isPinned(.systemCPU, onSystem: resolvedItem.systemID),
                onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .systemCPU) }
            )
        case .systemMemory:
            SystemMemoryChartView(
                xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.chartDataManager.isPinned(.systemMemory, onSystem: resolvedItem.systemID),
                onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .systemMemory) }
            )
        case .systemTemperature:
            SystemTemperatureChartView(
                xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                dataPoints: systemData,
                systemName: systemName,
                isPinned: homeViewModel.chartDataManager.isPinned(.systemTemperature, onSystem: resolvedItem.systemID),
                onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .systemTemperature) }
            )
        case .containerCPU(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerCpuChartView(
                    xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: homeViewModel.chartDataManager.isPinned(.containerCPU(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .containerCPU(name: container.name)) }
                )
            }
        case .containerMemory(let name):
            if let container = containerData.first(where: { $0.id == name }) {
                ContainerMemoryChartView(
                    xAxisFormat: homeViewModel.chartDataManager.xAxisFormat,
                    container: container,
                    systemName: systemName,
                    isPinned: homeViewModel.chartDataManager.isPinned(.containerMemory(name: container.name), onSystem: resolvedItem.systemID),
                    onPinToggle: { homeViewModel.chartDataManager.togglePin(for: .containerMemory(name: container.name)) }
                )
            }
        case .stackedContainerCPU:
            StackedCpuChartView(
                settingsManager: settingsManager,
                processedData: containerData,
                systemID: resolvedItem.systemID,
                systemName: systemName
            )
        case .stackedContainerMemory:
            StackedMemoryChartView(
                settingsManager: settingsManager,
                processedData: containerData,
                systemID: resolvedItem.systemID,
                systemName: systemName,
            )
        }
    }
}
