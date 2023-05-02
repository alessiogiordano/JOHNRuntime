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
                "yield": "headers"
            },
            {
                "url": "http://127.0.0.1:8080/john/combo/$2[content-length]",
                "headers": {
                    "john": "$2[content-length]"
                },
                "query": {
                    "john": "$2[content-length]"
                }
            }
        ],
        "result": {
            "json": "$1[text]",
            "text": "$2[content-length]",
            "combo": "$3"
        }
    }
    """
    func testParsing() throws {
        
        let desiredOutput = JOHN(about: .init(name: "Sample Plugin", version: 1, protocol: "Sample Protocol"), pipeline: [
            .init(url: "http://127.0.0.1:8080/john/json", method: "GET"),
            .init(url: "http://127.0.0.1:8080/john/text", yield: .headers),
            .init(url: "http://127.0.0.1:8080/john/combo/$2[content-length]", headers: ["john": "$2[content-length]"], query: ["john": "$2[content-length]"])
        ], result: ["json": "$1[text]", "text": "$2[content-length]", "combo": "$3"])
        let actualOutput = try! JSONDecoder().decode(JOHN.self, from: Self.examplePlugin.data(using: .utf8)!)
        
        XCTAssertEqual(desiredOutput, actualOutput)
    }
    func testFindOutTheProblem() async throws {
        XCTAssertTrue((try? JSONDecoder().decode(JOHN.self, from: """
        {
          "about": {
            "name": "Get Storage Quota - Onedrive File Provider",
            "version": 1,
            "protocol": "AUX_FileProvider_GetStorageQuota"
          },
          "result": {
            "used": "$1[used]",
            "total": "$1[total]",
            "available": "$1[remaining]"
          },
          "pipeline": [
            {
              "url": "https://graph.microsoft.com/v1.0/me/drive/quota",
              "method": "GET",
              "status": [
                200
              ],
              "authorization": "bearer"
            }
          ]
        }
        """.data(using: .utf8)!)) != nil)
    }
    /*
    func testExecution() async throws {
        let plugin = try! JSONDecoder().decode(JOHN.self, from: Self.examplePlugin.data(using: .utf8)!)
        let result = try await plugin.execute()
        
        XCTAssertEqual(result["json"] as! String, "This is a JSON Response")
        XCTAssertEqual(result["text"] as! String, "27")
        XCTAssertEqual(result["combo"] as! String, "path: 27 query: 27 header: 27")
        
    }
    */
}
