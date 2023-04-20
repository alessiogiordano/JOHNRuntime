//
//  Parameters.swift
//  
//
//  Created by Alessio Giordano on 18/04/23.
//

import Foundation

enum Parameters: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByDictionaryLiteral {
    case optional, required, defaultValue(String), object([String: Parameters]),
         username, password, token /// Special default values that get replaced by the corresponding credential value
    
    enum Error: Swift.Error { case missingRequiredParameters }
    
    /// ExpressibleByStringLiteral
    typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        switch value.uppercased() {
            case "username":    self = .username
            case "password":    self = .password
            case "token":       self = .token
            default:            self = .defaultValue(value)
        }
    }
    /// ExpressibleByBooleanLiteral
    typealias BooleanLiteralType = Bool
    public init(booleanLiteral value: Bool) {
        self = value ? .required : .optional
    }
    /// ExpressibleByDictionaryLiteral
    typealias Key = String
    typealias Value = Self
    public init(dictionaryLiteral elements: (String, Self)...) {
        var dictionary: [String: Self] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self = .object(dictionary)
    }
    /// Codable
    public init(from decoder: Decoder) throws {
        do {
            self = .object(try decoder.singleValueContainer().decode([String: Self].self))
        } catch {
            do {
                self = (try decoder.singleValueContainer().decode(Bool.self)) ? .required : .optional
            } catch {
                let value = try decoder.singleValueContainer().decode(String.self)
                self = .init(stringLiteral: value)
            }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .required:                 try container.encode(true)
            case .optional:                 try container.encode(false)
            case .defaultValue(let value):  try container.encode(value)
            case .object(let value):        try container.encode(value)
            case .username:                 try container.encode("username")
            case .password:                 try container.encode("password")
            case .token:                    try container.encode("token")
        }
    }
}

extension Execution {
    func verifyInput(_ input: JOHN.Options.Input?, with parameters: Parameters?) throws -> (any IOProtocol)? {
        return try verifyPayload(input?.ioPayload, with: parameters)
    }
    func verifyPayload(_ payload: (any IOProtocol)?, with parameters: Parameters?) throws -> (any IOProtocol)? {
        switch parameters {
        /// Optional values or no parameters at all will always match
        case .optional, .none:
            return payload
        /// Authorization value accessors
        case .username:
            if let credentials = self.credentials, case .basic(let username, _) = credentials {
                return IOPayload(text: username)
            } else { throw Parameters.Error.missingRequiredParameters }
        case .password:
            if let credentials = self.credentials, case .basic(_, let password) = credentials {
                return IOPayload(text: password)
            } else { throw Parameters.Error.missingRequiredParameters }
        case .token:
            if let credentials = self.credentials, case .bearer(let token) = credentials {
                return IOPayload(text: token)
            } else { throw Parameters.Error.missingRequiredParameters }
        /// Required value verification
        case .required:
            if payload != nil {
                return payload
            } else { throw Parameters.Error.missingRequiredParameters }
        /// Optional default value substitution
        case .defaultValue(let value):
            if payload != nil {
                return payload
            } else { return IOPayload(text: value) }
        /// Recursive verification
        case .object(let value):
            let requestedKeys: [String] = Array(value.keys)
            let remainingKeys: [String] = payload?.keys.filter { requestedKeys.contains($0) == false } ?? []
            var object: [String: Any] = [:]
            for key in requestedKeys {
                if let verifiedValue = try verifyPayload(payload?[key], with: value[key])?.wrappedValue {
                    object[key] = verifiedValue
                }
            }
            remainingKeys.forEach { key in
                if let wrappedValue = payload?[key] {
                    object[key] = wrappedValue
                }
            }
            return IOPayload(wrappedValue: object)
        }
    }
}
