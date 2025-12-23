import Foundation

struct SystemDataPoint: Identifiable, Sendable {
    var id: Date { date }
    
    let date: Date
    let cpu: Double
    let memoryPercent: Double
    let temperatures: [(name: String, value: Double)]
    
    let bandwidth: (upload: Double, download: Double)?
    let diskIO: (read: Double, write: Double)?
    let loadAverage: (l1: Double, l5: Double, l15: Double)?
}
