//
//  Stage.swift
//  
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation

struct Stage: Codable, Equatable {
    /// Execution.swift
    let id: String?
    let `defer`: Bool?
    /// Assertion.swift
    let assert: [String: Assertion]?
    /// Repetition.swift
    let `repeat`: Repetition?
    /// Merger.swift
    let merge: Merger?
    /// Authorization.swift
    let authorization: Authorization?
    /// Execution+Redirection.swift
    let redirects: Int?
    /// Fields
    let url: String
    let method: String?
    let status: [Int]?
    let headers: [String: String]?
    let query: [String: String]?
    let cookies: Cookies?
    let body: Body?
    /// Result value
    let yield: Yield?
    enum Yield: String, Codable, Equatable { case headers, body, cookies }
    /// Encoding and decoding
    let encode: Encode?
    enum Encode: String, Codable { case json, form }
    let decode: Decode?
    enum Decode: String, Codable { case auto, raw, json, form, xml, xmlJson = "xml-json", soap, soapJson = "soap-json", html, base64 }
    
    init(url: String, id: String? = nil, defer: Bool? = nil, assert: [String: Assertion]? = nil, `repeat`: Repetition? = nil, merge: Merger? = nil, authorization: Authorization? = nil, redirects: Int? = nil, method: String? = nil, status: [Int]? = nil, headers: [String: String]? = nil, query: [String: String]? = nil, cookies: Cookies? = nil, body: Body? = nil, yield: Yield? = nil, encode: Encode? = nil, decode: Decode? = nil) {
        /// Execution.swift
        self.id = id
        self.defer = `defer`
        /// Assertion.swift
        self.assert = assert
        /// Repetition.swift
        self.repeat = `repeat`
        /// Merger.swift
        self.merge = merge
        /// Authorization.swift
        self.authorization = authorization
        /// Redirection.swift
        self.redirects = redirects
        /// Fields
        self.url = url
        self.method = method
        self.status = status
        self.headers = headers
        self.query = query
        self.cookies = cookies
        self.body = body
        /// Result value
        self.yield = yield
        /// Encoding and decoding
        self.encode = encode
        self.decode = decode
    }
}
