import Foundation

struct StackedCpuData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}

struct StackedMemoryData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let yStart: Double
    let yEnd: Double
}

struct AggregatedCpuData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let cpu: Double
}

struct AggregatedMemoryData: Identifiable, Sendable {
    var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    let date: Date
    let name: String
    let memory: Double
}

