//
//  SettableValue+Initializer.swift
//  
//
//  Created by Alessio Giordano on 10/04/23.
//

import Foundation

public extension SettableWithRawValue {
    init?(executing plugin: JOHN, on group: JOHN.Group? = nil, with options: JOHN.Options = .none, at subscript: Subscript = .init()) async {
        guard let result = try? await plugin.execute(on: group, with: options),
              let rawValue = result[`subscript`]?.text else { return nil }
        self.init(rawValue)
    }
}
public extension SettableWithCollectionOfRawValues {
    init(executing plugin: JOHN, on group: JOHN.Group? = nil, with options: JOHN.Options = .none, at subscript: Subscript = .init()) async {
        if let result = try? await plugin.execute(on: group, with: options),
           let slice = result[`subscript`],
           let indices = slice.indices {
            self.init(indices.compactMap {
                return slice[$0]?.text
            })
        } else {
            self.init([])
        }
    }
}
