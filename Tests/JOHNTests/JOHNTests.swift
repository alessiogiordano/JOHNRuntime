//
//  JOHNTests.swift
//  
//
//  Created by Alessio Giordano on 21/12/22.
//

import XCTest
@testable import JOHN

final class JOHNTests: XCTestCase {
    static let examplePlugin = """
    {
        "about": { "name": "Sample Plugin", "version": 1, "protocol": "Sample Protocol" },
        "pipeline": [
            {
                "url": "http://127.0.0.1:8080/john/json",
                "method": "GET"
            },
            {
                "url": "http://127.0.0.1:8080/john/text",
                "yield": "header"
            },
            {
                "url": "http://127.0.0.1:8080/john/combo/$2.content-length",
                "header": {
                    "john": "$2.content-length"
                },
                "query": {
                    "john": "$2.content-length"
                }
            }
        ],
        "result": {
            "json": "$1.text",
            "text": "$2.content-length",
            "combo": "$3"
        }
    }
    """
    func testParsing() throws {
        
        let desiredOutput = JOHN(about: .init(name: "Sample Plugin", version: 1, protocol: "Sample Protocol", sha1: nil), pipeline: [
            .init(url: "http://127.0.0.1:8080/john/json", method: "GET", status: nil, header: nil, query: nil, body: nil, yield: nil),
            .init(url: "http://127.0.0.1:8080/john/text", method: nil, status: nil, header: nil, query: nil, body: nil, yield: .header),
            .init(url: "http://127.0.0.1:8080/john/combo/$2.content-length", method: nil, status: nil, header: ["john": "$2.content-length"], query: ["john": "$2"], body: nil, yield: nil)
        ], result: ["json": "$1.text", "text": "$2.content-length", "combo": "$3"])
        let actualOutput = try! JSONDecoder().decode(JOHN.self, from: Self.examplePlugin.data(using: .utf8)!)
        
        XCTAssertEqual(desiredOutput, actualOutput)
    }
    func testExecution() async throws {
        let plugin = try! JSONDecoder().decode(JOHN.self, from: Self.examplePlugin.data(using: .utf8)!)
        let result = try await plugin.execute()
        
        XCTAssertEqual(result["json"], "This is a JSON Response")
        XCTAssertEqual(result["text"], "27")
        XCTAssertEqual(result["combo"], "path: 27 query: 27 header: 27")
        
    }
}
