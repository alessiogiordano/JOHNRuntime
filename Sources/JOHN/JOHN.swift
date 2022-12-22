//
//  JOHN.swift
//  The JSON HTTP Notation
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation
import AsyncHTTPClient

public struct JOHN: Codable, Equatable {
    let about: Metadata
    let pipeline: [Request]
    let result: [String: String]
    
    func execute(on client: HTTPClient? = nil) async throws -> [String: String] {
        var responses: [Response?] = [nil]
        for request in pipeline {
            await responses.append(try request.execute(with: responses, on: client))
        }
        var result = self.result
        for element in result {
            result[element.key] = try Variable.substitute(responses: responses, in: element.value)
        }
        return result
    }
}
