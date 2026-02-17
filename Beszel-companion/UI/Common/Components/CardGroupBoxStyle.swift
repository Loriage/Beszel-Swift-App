import SwiftUI

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
            configuration.content
        }
        .padding()
        .background(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
