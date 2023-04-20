//
//  AnyResult+Subscript.Element+Key.swift
//  
//
//  Created by Alessio Giordano on 04/04/23.
//

import Foundation

extension Subscript.Element {
    public enum Key {
        case constant(String), pattern([Pattern])
    }
}

extension Subscript.Element.Key: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible, Equatable {
    /// ExpressibleByStringLiteral
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        var components: [Pattern] = []
        var buffer: String = ""
        let flush: () -> () = {
            if !buffer.isEmpty {
                components.append(.literal(buffer))
                buffer = ""
            }
        }
        for character in value {
            if character == "*" {
                flush()
                if case .any = components.last {
                    continue
                } else {
                    components.append(.any)
                }
            } else {
                buffer.append(character)
            }
        }
        if components.isEmpty && !buffer.isEmpty {
            self = .constant(buffer)
        } else {
            flush()
            self = .pattern(components)
        }
    }
    /// CustomStringConvertible
    public var description: String {
        switch self {
        case .constant(let value):      return value
        case .pattern(let components):  return components.map { "\($0)" }.joined()
        }
    }
    /// Specificity
    internal var specificity: Int {
        switch self {
        case .constant(_):  return .max
        case .pattern(let components):
            return components.reduce(0) { result, element in
                result + element.specificity
            }
        }
    }
    /// Placeholder
    internal var isPlaceholder: Bool {
        switch self {
        case .constant(_):   return false
        default:             return true
        }
    }
    /// Equatable
    public static func ~= (lhs: Subscript.Element.Key, rhs: Subscript.Element.Key) -> Bool {
        if case .constant(let lhs) = lhs {
            if case .constant(let rhs) = rhs {
                return lhs == rhs
            } else if case .pattern(let rhs) = rhs {
                return lhs ~= rhs
            }
        }
        if case .pattern(let lhs) = lhs {
            if case .pattern(let rhs) = rhs {
                return lhs == rhs
            } else if case .constant(let rhs) = rhs {
                return lhs ~= rhs
            }
        }
        return false
        
    }
    public static func == (lhs: Subscript.Element.Key, rhs: Subscript.Element.Key) -> Bool {
        if case .constant(let lhs) = lhs {
            if case .constant(let rhs) = rhs {
                return lhs == rhs
            } else {
                return false
            }
        }
        if case .pattern(let lhs) = lhs {
            if case .pattern(let rhs) = rhs {
                return lhs == rhs
            } else {
                return false
            }
        }
        return false
    }
}
