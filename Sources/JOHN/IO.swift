//
//  IO.swift
//  
//
//  Created by Alessio Giordano on 22/12/22.
//

import Foundation

public typealias Input = Output
public struct Output {
    let wrappedValue: Any
    
    let source: Source
    public enum Source { case single, pagination }
    
    var text: String? { wrappedValue as? String }
    subscript(_ index: Int) -> Output? {
        if let array = wrappedValue as? [Any] {
            return Output.init(wrappedValue: array[index])
        } else { return nil }
    }
    subscript(_ entry: String) -> Output? {
        if let dictionary = wrappedValue as? [String: Any] {
            return Output.init(wrappedValue: dictionary[entry] as Any)
        } else { return nil }
    }
    internal init(_ source: Source = .single, wrappedValue: Any) {
        self.wrappedValue = wrappedValue
        self.source = source
    }
    public init(_ source: Source = .single, text: String) {
        self.wrappedValue = text
        self.source = source
    }
    public init?(_ source: Source = .single, json: String) {
        guard let data = json.data(using: .utf8) else { return nil }
        self.init(source, json: data)
    }
    public init?(_ source: Source = .single, json: Data) {
        // options: .topLevelDictionaryAssumed is only available from macOS 12 onwards
        guard let json = try? JSONSerialization.jsonObject(with: json) else { return nil }
        self.wrappedValue = json
        self.source = source
    }
    public init(_ source: Source = .single, dictionary: [String: Any]) {
        self.wrappedValue = dictionary
        self.source = source
    }
    
    static func merge(_ source: Source = .single, items: Output...) -> Output {
        return Self.merge(items: items)
    }
    static func merge(_ source: Source = .single, items: [Output]) -> Output {
        return Self.init(source, wrappedValue: items.map {
            $0.wrappedValue
        })
    }
}
