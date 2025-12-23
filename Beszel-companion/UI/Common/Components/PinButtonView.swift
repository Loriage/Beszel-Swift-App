import SwiftUI

struct PinButtonView: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
    }
}
