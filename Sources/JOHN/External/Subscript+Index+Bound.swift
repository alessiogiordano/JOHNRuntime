//
//  AnyResult+Subscript.Element+Index+Bound.swift
//  
//
//  Created by Alessio Giordano on 05/04/23.
//

import Foundation

extension Subscript.Element.Index {
    public enum Bound: ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible, Equatable, Comparable {
        case variable(String), literal(Int)
        /// ExpressibleByIntegerLiteral
        public typealias IntegerLiteralType = Int
        public init(integerLiteral value: Int) {
            self = .literal(value)
        }
        /// ExpressibleByStringLiteral
        public typealias StringLiteralType = String
        public init(stringLiteral value: String) {
            if let integerValue = Int(value) {
                self = .literal(integerValue)
            } else {
                self = .variable(value)
            }
        }
        /// CustomStringConvertible
        public var description: String {
            switch self {
            case .literal(let integerValue): return "\(integerValue)"
            case .variable(let stringValue): return stringValue
            }
        }
        /// Variable resolution
        internal func resolveIfNecessary(from outputs: [(any IOProtocol)?], preferRightEndSide rhs: Bool = false) -> Bound {
            if case .variable(let string) = self {
                if let variable = try? Variable(string: string).resolve(with: outputs) {
                    if let double = variable.number {
                        return .literal(Int(double))
                    } else if let indices = variable.indices {
                        if rhs, let last = indices.last {
                            return .literal(last)
                        } else if let first = indices.first {
                            return .literal(first)
                        }
                    }
                }
            }
            return self
        }
        /// Equatable
        public static func == (lhs: Subscript.Element.Index.Bound, rhs: Subscript.Element.Index.Bound) -> Bool {
            if case .variable(let lhs) = lhs {
                if case .variable(let rhs) = rhs {
                    return lhs == rhs
                }
            }
            if case .literal(let lhs) = lhs {
                if case .literal(let rhs) = rhs {
                    return lhs == rhs
                }
            }
            return false
        }
        /// Comparable
        public static func > (lhs: Subscript.Element.Index.Bound, rhs: Subscript.Element.Index.Bound) -> Bool? {
            return rhs < lhs
        }
        public static func < (lhs: Subscript.Element.Index.Bound, rhs: Subscript.Element.Index.Bound) -> Bool? {
            if case .literal(let lhs) = lhs {
                if case .literal(let rhs) = rhs {
                    return lhs < rhs
                }
            }
            return nil
        }
    }
}
