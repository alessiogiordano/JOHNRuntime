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
    
    public func execute(on client: HTTPClient? = nil, with options: Options = .none) async throws -> [String: Any] {
        var outputs: [(any IOProtocol)?] = [options.input?.ioPayload]
        for stage in pipeline {
            do {
                var repetitionCap = 0
                switch options.repetitions {
                    case .allowed(let cap): repetitionCap = cap
                    default: break
                }
                /// Try pagination
                outputs.append(try await stage.repeat(until: repetitionCap, bearing: options.credentials, with: outputs, on: client))
            } catch Repetition.Error.notRequested {
                /// Single execution
                let output = try await stage.execute(with: outputs, bearing: options.credentials, on: client)
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
