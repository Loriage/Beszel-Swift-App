import Foundation

struct StatPoint: Identifiable {
    var id: Date { date } 
    let date: Date
    let cpu: Double
    let memory: Double
}

struct ProcessedContainerData: Identifiable {
    let id: String
    var name: String { id }
    var statPoints: [StatPoint]
}

struct SystemDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let cpu: Double
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]
}
