import SwiftUI
import Charts

func generateColors(for domainCount: Int) -> [Color] {
    if domainCount == 0 {
        return []
    }
    if domainCount == 1 {
        return [Color(hue: 0.6, saturation: 0.8, brightness: 0.95)]
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

func formatMemory(value: Double, fromUnit unit: String) -> String {
    let megaBytes = (unit == "GB") ? (value * 1024) : value
    
    if megaBytes >= 1024 {
        let gigaBytes = megaBytes / 1024
        
        return String(format: "%.1f GB", gigaBytes)
    } else {
        if megaBytes < 10 && megaBytes > 0 {
            return String(format: "%.1f MB", megaBytes)
        }
        
        return String(format: "%.0f MB", megaBytes)
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
