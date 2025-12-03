import Foundation

struct StatPoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let cpu: Double
    let memory: Double
}

struct ProcessedContainerData: Identifiable, Sendable {
    let id: String
    var name: String { id }
    var statPoints: [StatPoint]
}

struct SystemDataPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let cpu: Double
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]
}
