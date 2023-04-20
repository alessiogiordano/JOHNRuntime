//
//  Subscript+Element.swift
//  
//
//  Created by Alessio Giordano on 04/04/23.
//

import Foundation

extension Subscript {
    public enum Element {
        case any, key(Key), index(Index)
    }
}
extension Subscript.Element: Equatable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    // MARK: Expressible as String or Int
    /// ExpressibleByIntegerLiteral
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: Int) {
        self = .index(.constant(value))
    }
    /// ExpressibleByStringLiteral
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        if value.first(where: { $0 != "*" }) == nil {
            self = .any
        } else {
            let index: Index = .init(stringLiteral: value)
            if case .none = index {
                self = .key(.init(stringLiteral: value))
            } else {
                self = .index(index)
            }
        }
    }
    public var description: String {
        switch self {
        case .any:              return "*"
        case .index(let index): return "\(index)"
        case .key(let key):     return "\(key)"
        }
    }
    public func description(withParentheses: Bool = false) -> String {
        if withParentheses {
            return "[\(description)]"
        } else {
            return description
        }
    }
    
    // MARK: Specificity Rule
    var specificity: Int {
        switch self {
        case .any:              return .min
        case .index(let index): return index.specificity
        case .key(let key):     return key.specificity
        }
    }
    // MARK: Placeholder Rule
    var isPlaceholder: Bool {
        switch self {
        case .any:              return true
        case .index(let index): return index.isPlaceholder
        case .key(let key):     return key.isPlaceholder
        }
    }
    
    // MARK: Equatable
    public static func ~= (lhs: Subscript.Element, rhs: Subscript.Element) -> Bool {
        /// The presence of a simple placeholder [*] makes the assertion always succede
        if case .any = lhs { return true }
        if case .any = rhs { return true }
        /// Otherwise, only subscripts of the same type can be compared
        if case .index(let lhs) = lhs {
            if case .index(let rhs) = rhs {
                return lhs ~= rhs
            } else {
                return false
            }
        }
        if case .key(let lhs) = lhs {
            if case .key(let rhs) = rhs {
                return lhs ~= rhs
            } else {
                return false
            }
        }
        return false
    }
    public static func == (lhs: Subscript.Element, rhs: Subscript.Element) -> Bool {
        /// Simple placeholders [*]
        if case .any = lhs {
            if case .any = rhs {
                return true
            } else {
                return false
            }
        }
        /// Index subscript
        if case .index(let lhs) = lhs {
            if case .index(let rhs) = rhs {
                return lhs == rhs
            } else {
                return false
            }
        }
        /// Key subscript
        if case .key(let lhs) = lhs {
            if case .key(let rhs) = rhs {
                return lhs == rhs
            } else {
                return false
            }
        }
        return false
    }
    /*public static func !== (lhs: Subscript.Element, rhs: Subscript.Element) -> Bool {
        return !(lhs === rhs)
    }*/
}
