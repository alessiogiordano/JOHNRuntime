//
//  Result.swift
//  
//
//  Created by Alessio Giordano on 31/03/23.
//

import Foundation

indirect enum Result: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, ExpressibleByDictionaryLiteral {
    case constant(String), conditional(Condition), nested([String: Result])
    
    struct Condition: Codable, Equatable {
        let assert: [String: Assertion]?
        let `catch`: Result?
        let result: Result
    }
    
    func subscripts(verifying variables: [(IOProtocol)?], inheriting prefix: Subscript = .init()) -> [Subscript: String] {
        switch self {
        case .constant(let string):
            return .init(dictionaryLiteral: (prefix, string))
        case .conditional(let condition):
            do {
                try self.verifyAssertion(with: variables)
                return condition.result.subscripts(verifying: variables, inheriting: prefix)
            } catch {
                return condition.catch?.subscripts(verifying: variables, inheriting: prefix) ?? [:]
            }
        case .nested(let dictionary):
            return Dictionary(dictionary.map { (key, value) in
                return value.subscripts(verifying: variables,
                                        inheriting: prefix.appending(contentsOf: .init(stringLiteral: key, resolvingBoundsWith: variables))
                                       )
            }.flatMap { $0 }, uniquingKeysWith: { first, _ in first })
        }
    }
    /// ExpressibleByStringLiteral
    typealias StringLiteralType = String
    public init(stringLiteral rawValue: String) {
        self = .constant(rawValue)
    }
    /// ExpressibleByDictionaryLiteral
    typealias Key = String
    typealias Value = Result
    public init(dictionaryLiteral elements: (String, Result)...) {
        var dictionary: [String: Result] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self = .nested(dictionary)
    }
    /// Codable
    public init(from decoder: Decoder) throws {
        do {
            self = .conditional(try decoder.singleValueContainer().decode(Condition.self))
        } catch {
            do {
                self = .nested(try decoder.singleValueContainer().decode([String: Result].self))
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
