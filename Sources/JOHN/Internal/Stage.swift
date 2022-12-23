//
//  Stage.swift
//  
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation

struct Stage: Codable, Equatable {
    let url: String
    let method: String?
    let status: [Int]?
    let header: [String: String]?
    let query: [String: String]?
    let body: String?
    let yield: Yield?
    enum Yield: String, Codable, Equatable { case header, body }
}
