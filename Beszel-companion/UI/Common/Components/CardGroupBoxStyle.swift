import SwiftUI

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: MonitoringSpacing.standard) {
            configuration.label
            configuration.content
        }
        .monitoringCard()
    }
}
