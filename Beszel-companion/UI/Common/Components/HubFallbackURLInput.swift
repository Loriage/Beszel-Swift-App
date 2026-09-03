import SwiftUI

struct HubFallbackURLInput: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("hub.fallback.title")
                .font(.subheadline.weight(.semibold))
            TextField("hub.fallback.placeholder", text: $text)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("hub.fallback.title")
                .accessibilityIdentifier("hub.fallback.url")
            Text("hub.fallback.description")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !HubURL.isValidFallback(text) {
                Text("hub.fallback.invalidURL")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
