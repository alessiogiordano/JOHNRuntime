//
//  JOHN+Options.swift
//  
//
//  Created by Alessio Giordano on 11/03/23.
//

import Foundation

public struct Options {
    /// Repetition options
    public enum Repetitions {
        case allowed(cap: Int)
    }
    let repetitions: Repetitions?
    /// Input options for use at index [0] of the pipeline
    public enum Input {
        case text(String), json(Data), dictionary([String: Any]), array([Any]), webForm(String)
        static func json(_ string: String) -> Self? {
            guard let data = string.data(using: .utf8) else { return nil }
            return .json(data)
        }
        internal var ioPayload: IOPayload? {
            switch self {
            case .text(let string):
                return IOPayload(text: string)
            case .json(let data):
                return IOPayload(json: data)
            case .dictionary(let dictionary):
                return IOPayload(dictionary: dictionary)
            case .array(let array):
                return IOPayload(array: array)
            case .webForm(let string):
                return IOPayload(webForm: string)
            }
        }
    }
    let input: Input?
    /// Credentials options
    public enum Credentials {
        case basic(username: String, password: String), bearer(token: String)
    }
    let credentials: Credentials?
    
    public init(repetitions: Repetitions? = nil, input: Input? = nil, credentials: Credentials? = nil) {
        self.repetitions = repetitions
        self.input = input
        self.credentials = credentials
    }
    /// Convenience initializers
    public static func repetitionsAllowed(_ cap: Int) -> Self {
        return self.init(repetitions: .allowed(cap: cap))
    }
    public static func input(_ input: Input) -> Self {
        return self.init(input: input)
    }
    public static func credentials(_ credentials: Credentials) -> Self {
        return self.init(credentials: credentials)
    }
    public static var none: Options { return self.init() }
}
