import SwiftUI
import Charts

private struct ChartXDomainKey: EnvironmentKey {
    static let defaultValue: ClosedRange<Date>? = nil
}

private struct ChartShowXGridLinesKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var chartXDomain: ClosedRange<Date>? {
        get { self[ChartXDomainKey.self] }
        set { self[ChartXDomainKey.self] = newValue }
    }

    var chartShowXGridLines: Bool {
        get { self[ChartShowXGridLinesKey.self] }
        set { self[ChartShowXGridLinesKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func chartXScaleIfNeeded(_ domain: ClosedRange<Date>?) -> some View {
        if let domain {
            self.chartXScale(domain: domain)
        } else {
            self
        }
    }
}

/// Evenly-spaced tick dates inset from the domain edges by `marginFraction` of the span.
func insetTickDates(for domain: ClosedRange<Date>?, count: Int = 4, marginFraction: Double = 0.05) -> [Date] {
    guard let domain, count >= 2 else { return [] }
    let span = domain.upperBound.timeIntervalSince(domain.lowerBound)
    guard span > 0 else { return [] }
    let margin = span * marginFraction
    let innerStart = domain.lowerBound.addingTimeInterval(margin)
    let innerEnd = domain.upperBound.addingTimeInterval(-margin)
    let step = innerEnd.timeIntervalSince(innerStart) / Double(count - 1)
    return (0..<count).map { i in innerStart.addingTimeInterval(Double(i) * step) }
}

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

/// Adaptive y-axis label formatting based on domain max value.
func adaptiveAxisLabel(_ v: Double, domainMax: Double) -> String {
    if domainMax < 0.1 {
        return String(format: "%.3f", v)
    } else if domainMax < 1 {
        return String(format: "%.2f", v)
    } else if domainMax < 10 {
        return String(format: "%.1f", v)
    } else {
        return String(format: "%.0f", v)
    }
}

/// Computes a nice domain max and step size so that `.automatic` axis marks naturally include the top value.
func niceYDomain(maxVal: Double, desiredCount: Int = 4) -> (max: Double, step: Double) {
    guard maxVal > 0 else { return (100, 25) }
    let maxWithHeadroom = maxVal * 1.1
    let roughStep = maxWithHeadroom / Double(desiredCount)
    let magnitude = pow(10, floor(log10(roughStep)))
    let normalized = roughStep / magnitude
    let niceStep: Double
    if normalized <= 1 { niceStep = 1 * magnitude }
    else if normalized <= 2 { niceStep = 2 * magnitude }
    else if normalized <= 2.5 { niceStep = 2.5 * magnitude }
    else if normalized <= 5 { niceStep = 5 * magnitude }
    else { niceStep = 10 * magnitude }
    let niceMax = ceil(maxWithHeadroom / niceStep) * niceStep
    return (niceMax, niceStep)
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

private struct CommonChartCustomization: ViewModifier {
    @Environment(\.chartShowXGridLines) private var chartShowXGridLines
    let xAxisFormat: Date.FormatStyle
    let xDomain: ClosedRange<Date>?

    func body(content: Content) -> some View {
        content
            .chartXAxis {
                AxisMarks(values: insetTickDates(for: xDomain)) { _ in
                    if chartShowXGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    AxisValueLabel(format: xAxisFormat, anchor: .top, collisionResolution: .disabled)
                        .font(.caption2)
                }
            }
            .chartLegend(.hidden)
            .chartXScaleIfNeeded(xDomain)
            .frame(height: 250)
    }
}

extension View {
    func commonChartCustomization(xAxisFormat: Date.FormatStyle, xDomain: ClosedRange<Date>? = nil) -> some View {
        modifier(CommonChartCustomization(xAxisFormat: xAxisFormat, xDomain: xDomain))
    }
}
