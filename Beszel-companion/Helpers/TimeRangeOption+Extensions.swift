//
//  xAxisFormat.swift
//  Beszel
//
//  Created by Bruno DURAND on 21/06/2025.
//

import Foundation
import SwiftUI


extension TimeRangeOption {
    var xAxisFormat: Date.FormatStyle {
        switch self {
        case .lastHour, .last12Hours, .last24Hours:
            return .dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
        case .last7Days, .last30Days:
            return .dateTime.day(.twoDigits).month(.twoDigits)
        }
    }
}
