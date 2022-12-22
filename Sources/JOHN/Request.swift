//
//  Request.swift
//  
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation
import AsyncHTTPClient

enum RequestError: Error { case statusNotValid }
struct Request: Codable, Equatable {
    let url: String
    let method: String?
    let status: [Int]?
    let header: [String: String]?
    let query: [String: String]?
    let body: String?
    let yield: Yield?
    enum Yield: String, Codable, Equatable { case header, body }
    
    func execute(with variables: [Response?], on client: HTTPClient? = nil) async throws -> Response? {
        /// Setup HTTP Client if the user hasn't provided one
        let httpClient: HTTPClient = client ?? HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            if client == nil {
                httpClient.shutdown({ _ in })
            }
        }
        
        let url = try Variable.substitute(responses: variables, in: self.url, urlEncoded: true)
        var request = HTTPClientRequest(url: url)
        
        if let query, let url = URL(string: url) {
            request.url = url
                .appending(queryItems: try query.map { URLQueryItem(name: $0.key, value: try Variable.substitute(responses: variables, in: $0.value)) })
                .absoluteString
        }
        if let method { request.method = .init(rawValue: try Variable.substitute(responses: variables, in: method)) }
        if let header { request.headers = .init(try header.map { ($0.key, try Variable.substitute(responses: variables, in: $0.value)) }) }
        if let body { request.body = .bytes(.init(string: try Variable.substitute(responses: variables, in: body))) }
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        if let status, status.contains(Int(response.status.code)) == false {
            throw RequestError.statusNotValid
        }
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)
        guard let expectedBytes, expectedBytes > 0 else { return nil }
        if self.yield == .header {
            var headers: [String: Any] = [:]
            /// Reversed so that the first instance of a header replaces all the other ones
            response.headers.reversed().forEach { header in
                headers[header.name] = header.value
            }
            return Response(parsedJSON: headers)
        } else {
            let body = String(buffer: try await response.body.collect(upTo: expectedBytes))
            if response.headers.first(name: "content-type")?.contains("application/json") == true {
                return Response(json: body)
            } else {
                return Response(text: body)
            }
        }
    }
}
