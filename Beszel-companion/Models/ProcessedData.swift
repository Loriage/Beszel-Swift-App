import Foundation

struct StatPoint: Identifiable, Sendable, Hashable {
    var id: Date { date }
    let date: Date
    let cpu: Double
    let memory: Double
}

struct ProcessedContainerData: Identifiable, Sendable, Hashable {
    let id: String
    var name: String { id }
    var statPoints: [StatPoint]
}

struct SystemDataPoint: Identifiable, Sendable {
    var id: Date { date }
    
    let date: Date
    let cpu: Double
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]
}

struct AggregatedCpuData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let cpu: Double
}

struct StackedCpuData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}

struct AggregatedMemoryData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let memory: Double
}

struct StackedMemoryData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}
