//
//  DateFormatter+Extensions.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import Foundation

extension DateFormatter {
    static let pocketBase: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        return formatter
    }()
}
