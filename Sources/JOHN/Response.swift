//
//  Response.swift
//  
//
//  Created by Alessio Giordano on 22/12/22.
//

import Foundation

struct Response {
    let wrappedValue: Any
    var text: String? { wrappedValue as? String }
    subscript(_ index: Int) -> Response? {
        if let array = wrappedValue as? [Any] {
            return Response.init(wrappedValue: array[index])
        } else { return nil }
    }
    subscript(_ entry: String) -> Response? {
        if let dictionary = wrappedValue as? [String: Any] {
            return Response.init(wrappedValue: dictionary[entry] as Any)
        } else { return nil }
    }
    private init(wrappedValue: Any) {
        self.wrappedValue = wrappedValue
    }
    init(text: String) {
        self.wrappedValue = text
    }
    init?(json: String) {
        guard let data = json.data(using: .utf8) else { return nil }
        self.init(json: data)
    }
    init?(json: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: json) else { return nil }
        self.wrappedValue = json
    }
    init(parsedJSON: [String: Any]) {
        self.wrappedValue = parsedJSON
    }
}
