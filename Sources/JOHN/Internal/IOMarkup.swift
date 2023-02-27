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
    
    /// The text accessor is used to return the tag name
    let text: String?
    
    /// The array subscript is used to return the child nodes
    var indices: Range<Int>? {
        return wrappedChildren.indices
    }
    subscript(index: Int) -> (IOProtocol)? {
        return wrappedChildren[index]
    }
    
    /// The dictionary subscript is used to return the tag attributes
    var keys: [String] {
        return wrappedAttributes.keys
    }
    subscript(key: String) -> (IOProtocol)? {
        return wrappedAttributes[key]
    }
    
    // MARK: Initializers
    internal init(tagName: String? = nil, wrappedAttributes: any IOProtocol, wrappedChildren: any IOProtocol) {
        self.text = tagName
        self.wrappedAttributes = wrappedAttributes
        self.wrappedChildren = wrappedChildren
    }
}
