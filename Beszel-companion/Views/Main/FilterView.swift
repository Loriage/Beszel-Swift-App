import SwiftUI

struct FilterView: View {
    @Binding var sortOption: SortOption
    @Binding var sortDescending: Bool

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("dashboard.descending")) {
                    Toggle("dashboard.descending", isOn: $sortDescending)
                }

                Section(header: Text("dashboard.filterBy")) {
                    Picker("dashboard.filterBy", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("dashboard.filtersTitle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }
}
