import SwiftUI
import Charts

func generateColors(for domainCount: Int) -> [Color] {
    if domainCount == 0 {
        return []
    }
    return (0..<domainCount).map { i in

        let progress = Double(i) / Double(domainCount - 1)
        let hue = 0.8 * (1.0 - progress)
        return Color(hue: hue, saturation: 0.8, brightness: 0.95)
    }
}

func color(for containerName: String, in domain: [String]) -> Color {
    guard let index = domain.firstIndex(of: containerName),
          !domain.isEmpty else {
        return .gray
    }
    let colors = generateColors(for: domain.count)
    return colors[index]
}

func gradientForColor(_ color: Color) -> LinearGradient {
    return LinearGradient(
        colors: [color.opacity(0.6), color.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
}

func gradientRange(for domain: [String]) -> [LinearGradient] {
    if domain.isEmpty {
        return []
    }
    let colors = generateColors(for: domain.count)
    return colors.map { color in
        gradientForColor(color)
    }
}

extension View {
    func commonChartCustomization(xAxisFormat: Date.FormatStyle) -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: xAxisFormat, centered: true)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 250)
    }
}
