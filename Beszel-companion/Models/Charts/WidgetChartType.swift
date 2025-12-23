import Foundation

public enum WidgetChartType: String, Sendable, CaseIterable {
    case systemCPU
    case systemMemory
    case systemTemperature
    case systemInfo
    
    public var id: String { rawValue }
}
