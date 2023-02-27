//
//  Stage+Execution.swift
//  
//
//  Created by Alessio Giordano on 23/12/22.
//

import Foundation
import AsyncHTTPClient

extension Stage {
    enum ExecutionError: Error { case statusNotValid }
    func execute(with variables: [IOProtocol?], on client: HTTPClient? = nil, at url: String? = nil) async throws -> IOProtocol? {
        /// Setup HTTP Client if the user hasn't provided one
        let httpClient: HTTPClient = client ?? HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            if client == nil {
                httpClient.shutdown({ _ in })
            }
        }
        let url = try Variable.substitute(outputs: variables, in: url ?? self.url, urlEncoded: true)
        var request = HTTPClientRequest(url: url)
        
        if let query, let url = URL(string: url) {
            request.url = url
                .appending(queryItems: try query.map { URLQueryItem(name: $0.key, value: try Variable.substitute(outputs: variables, in: $0.value)) })
                .absoluteString
        }
        if let method { request.method = .init(rawValue: try Variable.substitute(outputs: variables, in: method)) }
        if let header { request.headers = .init(try header.map { ($0.key, try Variable.substitute(outputs: variables, in: $0.value)) }) }
        switch body {
            case .text(let body):
                request.body = .bytes(.init(string: try Variable.substitute(outputs: variables, in: body)))
            case .dictionary(let body):
                let substitutedBody = try body.reduce(into: [String: String]()) { body, element in
                    body[try Variable.substitute(outputs: variables, in: element.key)] = try Variable.substitute(outputs: variables, in: element.value)
                }
                switch self.encode {
                    case .form:
                        let encodedBody = substitutedBody.reduce(into: "") { output, element in
                            guard let key = element.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                                  let value = element.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                            else { return }
                            output += "\(output.count != 0 ? "&" : "")\(key)=\(value)"
                        }
                        request.body = .bytes(.init(string: encodedBody))
                    default:
                        request.body = .bytes(try JSONEncoder().encode(substitutedBody))
                }
            case .none: break
        }
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        if let status, status.contains(Int(response.status.code)) == false {
            throw ExecutionError.statusNotValid
        }
        if self.yield == .header {
            var headers: [String: Any] = [:]
            /// Reversed so that the first instance of a header replaces all the other ones
            response.headers.reversed().forEach { header in
                headers[header.name] = header.value
            }
            return IOPayload(dictionary: headers)
        } else {
            var body = ""
            for try await buffer in response.body {
                body.append(contentsOf: String(buffer: buffer))
            }
            var decodingStrategy: Decode = self.decode ?? .auto
            if decodingStrategy == .auto {
                if let contentType = response.headers.first(name: "content-type") {
                    if contentType.contains("application/json") {
                        decodingStrategy = .json
                    } else if contentType.contains("application/x-www-form-urlencoded") {
                        decodingStrategy = .form
                    } else if contentType.contains("text/xml") || contentType.contains("application/xml") || contentType.hasSuffix("+xml") {
                        decodingStrategy = .xml
                    } else {
                        decodingStrategy = .raw
                    }
                } else {
                    decodingStrategy = .raw
                }
            }
            switch decodingStrategy {
                case .json:
                    return IOPayload(json: body)
                case .form:
                    return IOPayload(webForm: body)
                case .xml:
                    /// public func getString(at index: Int, length: Int) -> String? in Swift-NIO always uses Unicode.UTF8.self encoding
                    return await IOMarkup(xml: body.data(using: .utf8))
                default:
                    return IOPayload(text: body)
            }
        }
    }
}
