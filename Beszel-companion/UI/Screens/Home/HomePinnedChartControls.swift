import SwiftUI

struct HomePinnedChartControls: View {
    @Binding var searchText: String
    let onFilter: () -> Void

    var body: some View {
        HStack(spacing: MonitoringSpacing.standard) {
            MonitoringSearchField(prompt: "dashboard.searchPlaceholder", text: $searchText)

            Button(action: onFilter) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("dashboard.filtersTitle")
        }
    }
}
