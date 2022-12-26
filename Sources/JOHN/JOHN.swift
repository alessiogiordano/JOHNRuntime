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
    
    public func execute(on client: HTTPClient? = nil, with input: Input? = nil) async throws -> [String: Any] {
        var outputs: [Output?] = [input]
        for stage in pipeline {
            if let handle = stage.paginate {
                await outputs.append(try stage.execute(paginating: handle, with: outputs, on: client))
            } else {
                await outputs.append(try stage.execute(with: outputs, on: client))
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
