//
//  ProcessedData.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import Foundation

struct StatPoint: Identifiable {
    let id = UUID()
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
