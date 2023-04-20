//
//  JOHN.swift
//  The JSON HTTP Notation
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation
import AsyncHTTPClient

public struct JOHN: Codable, Equatable, CustomStringConvertible {
    let about: About
    let parameters: Parameters?
    let pipeline: [Stage]
    let result: Result
    
    /// Initializers
    init(about: About, parameters: Parameters? = nil, pipeline: [Stage], result: Result) {
        self.about = about
        self.parameters = parameters
        self.pipeline = pipeline
        self.result = result
    }
    static func parse(string: String) -> Self? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    init?(string: String) {
        guard let parsed = Self.parse(string: string) else { return nil }
        self = parsed
    }
    
    /// CustomStringConvertible
    public func description(_ formatting: JSONEncoder.OutputFormatting? = nil) -> String {
        let encoder = JSONEncoder()
        if let formatting {
            encoder.outputFormatting = formatting
        }
        guard let jsonData = try? encoder.encode(self) else { return "" }
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    public var description: String {
        return description()
    }
    
    // MARK: Execution of JOHN Plugins
    /// AnyResult
    public func execute(on group: JOHN.Group? = nil, with options: JOHN.Options = .none) async throws -> AnyResult {
        try await group?.prepareForExecution(with: options)
        let context = try group?.context ?? Execution(with: options, parameters: self.parameters)
        // MARK: didStartPlugin Event
        context.delegate?.debug(didStartPlugin: self, withOptions: options.merging(options: group?.defaults))
        for stage in pipeline {
            let index = context.currentStageIndex
            // MARK: didStartStage Event
            context.delegate?.debug(didStartStage: index)
            do {
                var repetitionCap = 0
                switch options.repetitions {
                    case .allowed(let cap): repetitionCap = cap
                    default: break
                }
                /// Try pagination
                context.outputs.append(try await stage.repeat(until: repetitionCap, in: context))
            } catch Repetition.Error.notRequested {
                /// Single execution
                let output = try await stage.execute(in: context)
                var mergedVariables = try? stage.merge(from: context.outputs, with: context)
                if let output {
                    mergedVariables?.appendPage(output)
                }
                context.outputs.append(mergedVariables ?? output)
            }
            // MARK: didEndStage Event
            context.delegate?.debug(didEndStage: index, output: context.outputs.last??.wrappedValue)
        }
        if group == nil {
            try await context.executeDeferedRequests()
        }
        let result = AnyResult(rootOf: .init(context.outputs, result: self.result))
        // MARK: didEndPlugin Event
        context.delegate?.debug(didEndPlugin: self, result: result)
        return result
    }
    /// ExpectedResult
    public func decode<T: ExpectedResult>(_: T.Type, at path: Subscript = .init(), on group: JOHN.Group? = nil, with options: JOHN.Options = .none) async -> T? {
        return await execute(on: group, with: options, decoding: T.self, at: path)
    }
    public func execute<T: ExpectedResult>(on group: JOHN.Group? = nil, with options: JOHN.Options = .none, decoding: T.Type, at path: Subscript = .init()) async -> T? {
        return await T(executing: self, on: group, with: options, at: path)
    }
    /// SettableWithRawValue
    public func decode<T: SettableWithRawValue>(_: T.Type, at path: Subscript = .init(), on group: JOHN.Group? = nil, with options: JOHN.Options = .none) async -> T? {
        return await execute(on: group, with: options, decoding: T.self, at: path)
    }
    public func execute<T: SettableWithRawValue>(on group: JOHN.Group? = nil, with options: JOHN.Options = .none, decoding: T.Type, at path: Subscript = .init()) async -> T? {
        return await T(executing: self, on: group, with: options, at: path)
    }
    /// SettableWithCollectionOfRawValues
    public func decode<T: SettableWithCollectionOfRawValues>(_: T.Type, at path: Subscript = .init(), on group: JOHN.Group? = nil, with options: JOHN.Options = .none) async -> T? {
        return await execute(on: group, with: options, decoding: T.self, at: path)
    }
    public func execute<T: SettableWithCollectionOfRawValues>(on group: JOHN.Group? = nil, with options: JOHN.Options = .none, decoding: T.Type, at path: Subscript = .init()) async -> T? {
        return await T(executing: self, with: options, at: path)
    }
}

extension Optional: ExpressibleByStringLiteral,
                    ExpressibleByUnicodeScalarLiteral,
                    ExpressibleByExtendedGraphemeClusterLiteral where Wrapped == JOHN {
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .parse(string: value)
    }
}
