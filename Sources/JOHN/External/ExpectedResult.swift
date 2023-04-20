//
//  ExpectedResult.swift
//  
//
//  Created by Alessio Giordano on 06/04/23.
//

import Foundation

public protocol ExpectedResult {
    /// An initializer with no parameters is necessary to provide default values for all non-JOHN parsable properties in the synthetized initializers
    init()
}

extension ExpectedResult {
    public init?(executing plugin: JOHN, on group: JOHN.Group? = nil, with options: JOHN.Options = .none, at path: Subscript = .init()) async {
        guard let result = try? await plugin.execute(on: group, with: options),
              let slice = result[path] else { return nil }
        self.init(from: slice)
    }
    ///
    internal init(from result: AnyResult) {
        self.init()
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let expected = child.value as? any SettableValue {
                expected.set(from: result)
            }
        }
    }
}
