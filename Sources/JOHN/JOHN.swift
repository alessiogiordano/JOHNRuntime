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
    
    func execute(on client: HTTPClient? = nil, with input: Input? = nil) async throws -> [String: String] {
        var outputs: [Output?] = [input]
        for stage in pipeline {
            await outputs.append(try stage.execute(with: outputs, on: client))
        }
        var result = self.result
        for element in result {
            result[element.key] = try Variable.substitute(outputs: outputs, in: element.value)
        }
        return result
    }
}
