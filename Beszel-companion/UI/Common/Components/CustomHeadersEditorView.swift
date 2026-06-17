import SwiftUI

/// Edits a set of custom HTTP headers (name/value pairs) and returns the result
/// via `onSave`. Reused by onboarding and per-instance settings.
struct CustomHeadersEditorView: View {
    let onSave: ([String: String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pairs: [HeaderPair]

    private struct HeaderPair: Identifiable {
        let id = UUID()
        var name: String
        var value: String
    }

    init(headers: [String: String], onSave: @escaping ([String: String]) -> Void) {
        self.onSave = onSave
        let initial = headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { HeaderPair(name: $0.key, value: $0.value) }
        _pairs = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($pairs) { $pair in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("headers.namePlaceholder", text: $pair.name)
                                .font(.subheadline.weight(.medium))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            TextField("headers.valuePlaceholder", text: $pair.value)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { pairs.remove(atOffsets: $0) }

                    Button {
                        pairs.append(HeaderPair(name: "", value: ""))
                    } label: {
                        Label("headers.add", systemImage: "plus")
                    }
                } footer: {
                    Text("headers.description")
                }
            }
            .navigationTitle("headers.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                }
            }
        }
    }

    private func save() {
        var result: [String: String] = [:]
        for pair in pairs {
            let name = pair.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            result[name] = pair.value.trimmingCharacters(in: .whitespaces)
        }
        onSave(result)
        dismiss()
    }
}
