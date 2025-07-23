import SwiftUI

struct ScreenHeaderView: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}
