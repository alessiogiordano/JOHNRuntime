//
//  Result.swift
//  
//
//  Created by Alessio Giordano on 31/03/23.
//

import Foundation

indirect enum Result: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, ExpressibleByDictionaryLiteral {
    case constant(String), conditional(Condition), nested([Subscript: Result])
    
    struct Condition: Codable, Equatable {
        let assert: [String: Assertion]?
        let `catch`: Result?
        let result: Result
    }
    
    /// ExpressibleByStringLiteral
    typealias StringLiteralType = String
    public init(stringLiteral rawValue: String) {
        self = .constant(rawValue)
    }
    /// ExpressibleByDictionaryLiteral
    typealias Key = Subscript
    typealias Value = Result
    public init(dictionaryLiteral elements: (Subscript, Result)...) {
        var dictionary: [Subscript: Result] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self = .nested(dictionary)
    }
    /// Codable
    public init(from decoder: Decoder) throws {
        do {
            self = .conditional(try decoder.singleValueContainer().decode(Condition.self))
        } catch {
            do {
                /// https://github.com/apple/swift-evolution/blob/main/proposals/0320-codingkeyrepresentable.md
                /// The current conformance of Swift's Dictionary to the Codable protocols has a somewhat-surprising limitation in that dictionaries whose key type is not String or Int (values directly representable in CodingKey types) encode not as KeyedContainers but as UnkeyedContainers.
                self = .nested(
                    try decoder.singleValueContainer().decode([String: Result].self)
                        .reduce(into: [Subscript: Result]()) { dictionary, tuple in
                            dictionary[Subscript(stringLiteral: tuple.key)] = tuple.value
                        }
                )
            } catch {
                self = .constant(try decoder.singleValueContainer().decode(String.self))
            }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .constant(let rawValue):    try container.encode(rawValue)
            case .conditional(let rawValue): try container.encode(rawValue)
            case .nested(let rawValue):      try container.encode(rawValue)
        }
    }
}
