//
//  Body.swift
//  
//
//  Created by Alessio Giordano on 26/02/23.
//

import Foundation

enum Body: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, ExpressibleByDictionaryLiteral {
    case text(String), dictionary([String: DictionaryValue])
    
    /// Allowing raw booleans and numbers in the dictionary
    enum DictionaryValue: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, CustomStringConvertible {
        case string(String), number(Double), boolean(Bool)
        
        /// CustomStringConvertible
        var description: String {
            switch self {
            case .string(let rawValue): return rawValue
            case .number(let rawValue): return rawValue.description
            case .boolean(let rawValue): return rawValue ? "true" : "false"
            }
        }
        
        /// ExpressibleByStringLiteral
        typealias StringLiteralType = String
        public init(stringLiteral value: String) {
            self = .string(value)
        }
        /// ExpressibleByFloatLiteral
        typealias FloatLiteralType = Float
        init(floatLiteral value: Float) {
            self = .number(.init(value))
        }
        /// ExpressibleByBooleanLiteral
        typealias BooleanLiteralType = Bool
        init(booleanLiteral value: Bool) {
            self = .boolean(value)
        }
        
        /// Codable
        public init(from decoder: Decoder) throws {
            do {
                self = .boolean(try decoder.singleValueContainer().decode(Bool.self))
            } catch {
                do {
                    self = .number(try decoder.singleValueContainer().decode(Double.self))
                } catch {
                    self = .string(try decoder.singleValueContainer().decode(String.self))
                }
            }
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .string(let rawValue):     try container.encode(rawValue)
                case .number(let rawValue):     try container.encode(rawValue)
                case .boolean(let rawValue):    try container.encode(rawValue)
            }
        }
    }
    /// ExpressibleByStringLiteral
    typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .text(value)
    }
    /// ExpressibleByDictionaryLiteral
    typealias Key = String
    typealias Value = DictionaryValue
    public init(dictionaryLiteral elements: (String, DictionaryValue)...) {
        var dictionary: [String: DictionaryValue] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self = .dictionary(dictionary)
    }
    
    /// Codable
    public init(from decoder: Decoder) throws {
        do {
            self = .dictionary(try decoder.singleValueContainer().decode([String: DictionaryValue].self))
        } catch {
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
