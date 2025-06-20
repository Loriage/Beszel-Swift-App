//
//  PocketBaseResponse.swift
//  Beszel-companion
//
//  Created by Bruno DURAND on 20/06/2025.
//

import Foundation

struct PocketBaseListResponse<T: Codable>: Codable {
    let page: Int
    let perPage: Int
    let totalItems: Int
    let totalPages: Int
    let items: [T]
}
