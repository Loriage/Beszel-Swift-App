import SwiftUI

struct FilterView: View {
    @Binding var layout: DashboardLayout
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                if layout.sortOption != .custom {
                    Section(header: Text("dashboard.descending")) {
                        Toggle("dashboard.sortByOrder", isOn: $layout.sortDescending)
                    }
                }
                
                Section(header: Text("dashboard.sortBy")) {
                    Picker("dashboard.sortBy", selection: $layout.sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("dashboard.filtersTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}
