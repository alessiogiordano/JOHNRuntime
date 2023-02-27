//
//  JOHN.swift
//  The JSON HTTP Notation
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation
import AsyncHTTPClient

public struct JOHN: Codable, Equatable {
    let about: About
    let pipeline: [Stage]
    let result: [String: String]
    
    static func parse(string: String) -> Self? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: nil)
    }
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, withTextInput string: String) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: IOPayload(text: string))
    }
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, withJSONInput string: String) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: IOPayload(json: string))
    }
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, withJSONInput data: Data) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: IOPayload(json: data))
    }
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, withDictionaryInput dictionary: [String: Any]) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: IOPayload(dictionary: dictionary))
    }
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, withArrayInput array: [Any]) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: IOPayload(array: array))
    }
    public func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, withWebFormInput webForm: String) async throws -> [String: Any] {
        return try await self.execute(on: client, limitRepeatAt: cap, with: IOPayload(webForm: webForm))
    }
    
    
    private func execute(on client: HTTPClient? = nil, limitRepeatAt cap: Int, with input: (any IOProtocol)? = nil) async throws -> [String: Any] {
        var outputs: [(any IOProtocol)?] = [input]
        for stage in pipeline {
            do {
                /// Try pagination
                outputs.append(try await stage.repeat(until: cap, with: outputs, on: client))
            } catch {
                /// Single execution
                let output = try await stage.execute(with: outputs, on: client)
                var mergedVariables = try? stage.merge(from: outputs)
                if let output {
                    mergedVariables?.appendPage(output)
                }
                outputs.append(mergedVariables ?? output)
            }
        }
        var result: [String: Any] = [:]
        for element in self.result {
            if let textValue = try? Variable.substitute(outputs: outputs, in: element.value) {
                result[element.key] = textValue
            } else {
                result[element.key] = try Variable(string: element.value).resolve(with: outputs).wrappedValue
            }
        }
        return result
    }
}
