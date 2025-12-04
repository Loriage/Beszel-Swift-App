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
