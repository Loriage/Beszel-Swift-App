import Foundation

struct SystemDataPoint: Identifiable, Sendable {
    var id: Date { date }
    
    let date: Date
    let cpu: Double
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]
}
