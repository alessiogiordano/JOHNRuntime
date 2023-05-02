//
//  Body.swift
//  
//
//  Created by Alessio Giordano on 26/02/23.
//

import Foundation

enum Body: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, ExpressibleByDictionaryLiteral {
    case text(String), dictionary([String: DictionaryValue]), object(ObjectValue)
    
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
    
    /// Allow expressing JSON objects as-is
    enum ObjectValue: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
        case value(DictionaryValue), array([ObjectValue]), dictionary([String: ObjectValue])
        
        func mapValues(_ transformValue: (DictionaryValue) throws -> DictionaryValue, mapKeys transformKey: ((String) throws -> String)? = nil) rethrows -> Self {
            switch self {
            case .value(let value):         return .value(try transformValue(value))
            case .array(let values):        return .array(try values.map { try $0.mapValues(transformValue, mapKeys: transformKey) })
            case .dictionary(let values):
                if let transformKey {
                    return .dictionary(try values.reduce(into: [String: Self]()) { dictionary, element in
                        dictionary[try transformKey(element.key)] = try element.value.mapValues(transformValue, mapKeys: transformKey)
                    })
                } else { return .dictionary(try values.mapValues { try $0.mapValues(transformValue, mapKeys: nil) } ) }
            }
        }
        
        /// ExpressibleByStringLiteral
        typealias StringLiteralType = String
        public init(stringLiteral value: String) {
            self = .value(.init(stringLiteral: value))
        }
        /// ExpressibleByFloatLiteral
        typealias FloatLiteralType = Float
        init(floatLiteral value: Float) {
            self = .value(.init(floatLiteral: value))
        }
        /// ExpressibleByBooleanLiteral
        typealias BooleanLiteralType = Bool
        init(booleanLiteral value: Bool) {
            self = .value(.init(booleanLiteral: value))
        }
        /// ExpressibleByArrayLiteral
        typealias ArrayLiteralElement = Self
        init(arrayLiteral elements: ArrayLiteralElement...) {
            self = .array(elements)
        }
        /// ExpressibleByDictionaryLiteral
        typealias Key = String
        typealias Value = Self
        public init(dictionaryLiteral elements: (Key, Value)...) {
            var dictionary: [Key: Value] = [:]
            elements.forEach { dictionary[$0.0] = $0.1 }
            self = .dictionary(dictionary)
        }
        
        /// Codable
        public init(from decoder: Decoder) throws {
            do {
                self = .value(try decoder.singleValueContainer().decode(DictionaryValue.self))
            } catch {
                do {
                    self = .array(try decoder.singleValueContainer().decode([ArrayLiteralElement].self))
                } catch {
                    self = .dictionary(try decoder.singleValueContainer().decode([Key: Value].self))
                }
            }
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .value(let rawValue):      try container.encode(rawValue)
                case .array(let rawValue):      try container.encode(rawValue)
                case .dictionary(let rawValue): try container.encode(rawValue)
            }
        }
    }
    
    /// ExpressibleByStringLiteral
    typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .text(value)
    }
    /// ExpressibleByDictionaryLiteral
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
            do {
                self = .object(try decoder.singleValueContainer().decode(ObjectValue.self))
            } catch {
                self = .text(try decoder.singleValueContainer().decode(String.self))
            }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .text(let rawValue):       try container.encode(rawValue)
            case .dictionary(let rawValue): try container.encode(rawValue)
            case .object(let rawValue):     try container.encode(rawValue)
        }
    }
}
