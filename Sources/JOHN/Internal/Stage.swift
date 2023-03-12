//
//  Stage.swift
//  
//
//  Created by Alessio Giordano on 21/12/22.
//

import Foundation

struct Stage: Codable, Equatable {
    /// Stage+Assertion
    let assert: [String: Assertion]?
    /// Stage+Repetition
    let `repeat`: Repetition?
    /// Stage+Merger
    let merge: Merger?
    /// Stage+Authorization
    let authorization: Authorization?
    /// Fields
    let url: String
    let method: String?
    let status: [Int]?
    let header: [String: String]?
    let query: [String: String]?
    let body: Body?
    /// Result value
    let yield: Yield?
    enum Yield: String, Codable, Equatable { case header, body }
    /// Encoding and decoding
    let encode: Encode?
    enum Encode: Codable { case json, form }
    let decode: Decode?
    enum Decode: Codable { case auto, raw, json, form, xml }
    
    init(url: String, assert: [String: Assertion]? = nil, `repeat`: Repetition? = nil, merge: Merger? = nil, authorization: Authorization? = nil , method: String? = nil, status: [Int]? = nil, header: [String: String]? = nil, query: [String: String]? = nil, body: Body? = nil, /*body: String? = nil, paginate: String? = nil,*/ yield: Yield? = nil, encode: Encode? = nil, decode: Decode? = nil) {
        /// Stage+Assertion
        self.assert = assert
        /// Stage+Repetition
        self.repeat = `repeat`
        /// Stage+Merger
        self.merge = merge
        /// Stage+Authorization
        self.authorization = authorization
        /// Fields
        self.url = url
        self.method = method
        self.status = status
        self.header = header
        self.query = query
        self.body = body
        /// Result value
        self.yield = yield
        /// Encoding and decoding
        self.encode = encode
        self.decode = decode
    }
}
