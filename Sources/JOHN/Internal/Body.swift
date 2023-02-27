//
//  Body.swift
//  
//
//  Created by Alessio Giordano on 26/02/23.
//

import Foundation

enum Body: Codable, Equatable {
    case text(String), dictionary([String: String])
    
    public init(rawValue: String) {
        self = .text(rawValue)
    }
    public init(rawValue: [String: String]) {
        self = .dictionary(rawValue)
    }
    
    public init(from decoder: Decoder) throws {
        do {
            self = .dictionary(try decoder.singleValueContainer().decode([String : String].self))
        } catch DecodingError.typeMismatch {
            self = .text(try decoder.singleValueContainer().decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .text(let rawValue):       try container.encode(rawValue)
            case .dictionary(let rawValue): try container.encode(rawValue)
        }
    }
}
