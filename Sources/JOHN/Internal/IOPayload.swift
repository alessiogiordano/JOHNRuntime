//
//  IOPayload.swift
//  
//
//  Created by Alessio Giordano on 21/02/23.
//

import Foundation

struct IOPayload: IOProtocol {
    let wrappedValue: Any
    
    var text: String? {
        return (wrappedValue as? String) ?? (
            (wrappedValue as? Double) != nil || (wrappedValue as? Bool) != nil
                ? (wrappedValue as? CustomStringConvertible)?.description
                : nil
        )
    }
    var number: Double? {
        return wrappedValue as? Double ?? (
            (wrappedValue as? String) != nil ? Double(wrappedValue as! String) : nil
        )
    }
    var boolean: Bool? {
        return wrappedValue as? Bool ?? (
            (wrappedValue as? String)?.lowercased() == "true" ? true : (wrappedValue as? String)?.lowercased() == "false" ? false : nil
        )
    }
    
    var indices: Range<Int>? {
        if let array = wrappedValue as? [Any] {
            return array.indices
        } else {
            return nil
        }
    }
    subscript(_ index: Int) -> (any IOProtocol)? {
        if let array = wrappedValue as? [Any] {
            /// Prevent double-wrapping of IOProtocol types
            return (array[index] as? (any IOProtocol)) ?? IOPayload.init(wrappedValue: array[index])
        } else { return nil }
    }
    
    var keys: [String] {
        if let dictionary = wrappedValue as? [String: Any] {
            return dictionary.keys.map { $0 }
        } else {
            return []
        }
    }
    subscript(_ key: String) -> (any IOProtocol)? {
        if let dictionary = wrappedValue as? [String: Any] {
            /// Prevent double-wrapping of IOProtocol types
            return (dictionary[key] as? (any IOProtocol)) ?? IOPayload.init(wrappedValue: dictionary[key] as Any)
        } else { return nil }
    }
    
    // MARK: Initializers
    internal init(wrappedValue: Any) {
        self.wrappedValue = wrappedValue
    }
    public init(text: String) {
        self.wrappedValue = text
    }
    public init?(json: String) {
        guard let data = json.data(using: .utf8) else { return nil }
        self.init(json: data)
    }
    public init?(json: Data) {
        // options: .topLevelDictionaryAssumed is only available from macOS 12 onwards
        guard let json = try? JSONSerialization.jsonObject(with: json) else { return nil }
        self.wrappedValue = json
    }
    public init(dictionary: [String: Any]) {
        self.wrappedValue = dictionary
    }
    public init(array: [Any]) {
        self.wrappedValue = array
    }
    public init?(webForm: String) {
        let dictionary = webForm
            .split(separator: "&")
            .reduce(into: [String: String]()) { result, element in
                let components = element.split(separator: "=")
                guard components.count == 2,
                      let key = components.first?.removingPercentEncoding,
                      let value = components.last?.removingPercentEncoding
                else { return }
                result[key] = value
            }
        guard dictionary.isEmpty == false else { return nil }
        self.init(dictionary: dictionary)
    }
}
