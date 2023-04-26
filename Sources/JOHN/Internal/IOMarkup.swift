//
//  IOMarkup.swift
//  
//
//  Created by Alessio Giordano on 25/02/23.
//

import Foundation

struct IOMarkup: IOProtocol {
    let wrappedAttributes: any IOProtocol
    let wrappedChildren: any IOProtocol
    var wrappedValue: Any {
        return [
            "attributes": wrappedAttributes.wrappedValue,
            "children": wrappedChildren.wrappedValue
        ]
    }
    let caseInsensitive: Bool
    
    /// The text accessor is used to return the tag name
    let text: String?
    /// The number and boolean accessors do not make sense in this context
    let number: Double? = nil
    let boolean: Bool? = nil
    
    /// The array subscript is used to return the child nodes
    var indices: Range<Int>? {
        return wrappedChildren.indices
    }
    subscript(index: Int) -> (IOProtocol)? {
        return wrappedChildren[index]
    }
    
    /// The dictionary subscript is used to return the tag attributes
    var keys: [String] {
        if caseInsensitive {
            return wrappedAttributes.keys.map { $0.uppercased() }
        } else {
            return wrappedAttributes.keys
        }
    }
    subscript(key: String) -> (IOProtocol)? {
        if caseInsensitive {
            return wrappedAttributes[key.uppercased()]
        } else {
            return wrappedAttributes[key]
        }
    }
    /*
     subscript(key: String) -> (IOProtocol)? {
         /// Case insensitive attributes and tag names are treated as their uppercased counterpart
         let key = caseInsensitive ? key.uppercased() : key
         let attribute = attribute(key)
         let children = children(key)
         if attribute == nil && children.isEmpty { return nil }
         return Self.init(tagName: attribute, wrappedAttributes: IOPayload(array: []), wrappedChildren: IOPayload(array: children))
     }
     internal func attribute(_ key: String) -> String? {
         return wrappedAttributes[key]?.text
     }
     internal func children(_ key: String) -> [Self] {
         return wrappedChildren.indices?.compactMap {
             if let markup = (wrappedChildren[$0] as? Self),
                    markup.text == key {
                 return markup
             } else { return nil }
         } ?? []
     }
    */
    
    // MARK: Initializers
    internal init(tagName: String? = nil, wrappedAttributes: any IOProtocol, wrappedChildren: any IOProtocol, caseInsensitive: Bool = false) {
        if caseInsensitive {
            self.text = tagName?.uppercased()
        } else {
            self.text = tagName
        }
        self.wrappedAttributes = wrappedAttributes
        self.wrappedChildren = wrappedChildren
        self.caseInsensitive = caseInsensitive
    }
}
