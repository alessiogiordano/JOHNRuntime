//
//  JOHN+Options.swift
//  
//
//  Created by Alessio Giordano on 11/03/23.
//

import Foundation
import AsyncHTTPClient
import NIOCore

extension JOHN {
    public struct Options {
        /// EventLoopGroup used in HTTPClient
        public enum Provider {
            case createNew, sharedEventLoop(any EventLoopGroup)
        }
        let provider: Provider
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
        
        /// A delegate object that receives messages about the execution process.
        weak var delegate: (any DebugDelegate)?
        
        public init(provider: Provider = .createNew, repetitions: Repetitions? = nil, input: Input? = nil, credentials: Credentials? = nil, debug: (any DebugDelegate)? = nil) {
            self.provider = provider
            self.repetitions = repetitions
            self.input = input
            self.credentials = credentials
            self.delegate = debug
        }
        /// Convenience initializers
        public static func repetitionsAllowed(_ cap: Int, on provider: Provider = .createNew) -> Self {
            return self.init(provider: provider, repetitions: .allowed(cap: cap))
        }
        public static func input(_ input: Input, on provider: Provider = .createNew) -> Self {
            return self.init(provider: provider, input: input)
        }
        public static func credentials(_ credentials: Credentials, on provider: Provider = .createNew) -> Self {
            return self.init(provider: provider, credentials: credentials)
        }
        public static func debug(_ debug: (any DebugDelegate)?, on provider: Provider = .createNew) -> Self {
            return self.init(provider: provider, debug: debug)
        }
        public static func provider(_ provider: Provider) -> Self {
            return self.init(provider: provider)
        }
        public static var none: JOHN.Options { return self.init() }
        /// Merge options
        func merging(options: JOHN.Options?) -> Options {
            if let options {
                return merging(options: options)
            } else {
                return self
            }
        }
        func merging(options: JOHN.Options) -> Options {
            return .init(provider: self.provider, repetitions: self.repetitions ?? options.repetitions, input: self.input ?? options.input, credentials: self.credentials ?? options.credentials, debug: self.delegate ?? options.delegate)
        }
    }
}
