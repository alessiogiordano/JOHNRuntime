//
//  AnyResult+Subscript.Element+Index.swift
//  
//
//  Created by Alessio Giordano on 04/04/23.
//

import Foundation

extension Subscript.Element {
    public enum Index {
        case constant(Int), floor(Bound), range(lhs: Bound, rhs: Bound), none
    }
}

extension Subscript.Element.Index: RawRepresentable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible, ExpressibleByNilLiteral, Equatable {
    // MARK: RawRepresentable as Range
    /// Struct  <-- ArrayLiteral Conversion
    public typealias RawValue = Optional<Range<Int>>
    public init(rawValue: RawValue) {
        guard let rawValue else {
            self = .none
            return
        }
        self = .range(lhs: .init(integerLiteral: rawValue.lowerBound), rhs: .init(integerLiteral: rawValue.upperBound))
    }
    /// Struct --> ArrayLiteral Conversion
    public var rawValue: RawValue {
        if case .range(let lowerBound, let upperBound) = self, case .literal(let lhs) = lowerBound, case .literal(let rhs) = upperBound {
            return lhs..<rhs+1
        } else {
            return nil
        }
    }
    
    /// ExpressibleByIntegerLiteral
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: Int) {
        self = .constant(value)
    }
    /// ExpressibleByStringLiteral
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        if value.isEmpty {
            self = .none
        } else if let integerValue = Int(value) {
            self = .constant(integerValue)
        } else {
            let range = value.split(separator: "*")
            guard range.count < 2 else { self = .none; return }
            if let first = range.first {
                if let last = range.last {
                    if first.last == "<" && last.first == "<" {
                        /// Both the lower and the upper bounds are explicitly defined
                        self = .range(lhs: .init(stringLiteral: String(first)), rhs: .init(stringLiteral: String(last)))
                    } else {
                        self = .none
                    }
                } else {
                    if first.last == "<" {
                        /// There is not enough information to infer a range, but defining a lower threshold is still possible
                        self = .floor(.init(stringLiteral: String(first)))
                    } else if first.first == "<" {
                        /// Range with 0 as the lower bound
                        self = .range(lhs: .literal(0), rhs: .init(stringLiteral: String(first)))
                    } else {
                        self = .none
                    }
                }
            } else {
                self = .none
            }
        }
    }
    public var description: String {
        switch self {
        case .constant(let integerValue):
            return "\(integerValue)"
        case .floor(let lhs):
            return "\(lhs)<*"
        case .range(lhs: let lhs, rhs: let rhs):
            return "\(lhs)<*<\(rhs)"
        case .none:
            return ""
        }
    }
    /// ExpressibleByNilLiteral
    public init(nilLiteral: ()) {
        self = .none
    }
    /// Specificity
    internal var specificity: Int {
        switch self {
        case .constant(_):
            return .max
        case .none:
            return .min
        default:
            return 0
        }
    }
    /// Placeholder
    internal var isPlaceholder: Bool {
        switch self {
        case .constant(_), .none:   return false
        default:                    return true
        }
    }
    /// Variable resolution
    internal func resolveIfNecessary(from outputs: [(any IOProtocol)?]) -> Self {
        switch self {
        case .floor(let lhs):
            return .floor(lhs.resolveIfNecessary(from: outputs))
        case .range(let lhs, let rhs):
            return .range(lhs: lhs.resolveIfNecessary(from: outputs), rhs: rhs.resolveIfNecessary(from: outputs, preferRightEndSide: true))
        default: return self
        }
    }
    /// Equatable
    /// case constant(Int), floor(Bound), range(lhs: Bound, rhs: Bound), none
    public static func ~= (lhs: Subscript.Element.Index, rhs: Int) -> Bool {
        return rhs ~= lhs
    }
    public static func ~= (lhs: Int, rhs: Subscript.Element.Index) -> Bool {
        switch rhs {
        case .constant(let rhs):            return lhs == rhs
        case .floor(let rhs):               return .literal(lhs) > rhs
        case .range(let lower, let upper):  return (lower < .literal(lhs + 1)) && (.literal(lhs - 1) < upper)
        case .none:                         return false
        }
    }
    public static func ~= (lhs: Subscript.Element.Index, rhs: Subscript.Element.Index) -> Bool {
        if case .constant(let lhs) = lhs {
            return lhs ~= rhs
        }
        if case .constant(let rhs) = rhs {
            return rhs ~= lhs
        }
        if case .floor(let lhs) = lhs {
            switch rhs {
            case .floor(let rhs):       return lhs ~= rhs
            case .range(let rhs, _):    return lhs ~= rhs
            default:                    return false
            }
        }
        if case .range(let lhs_lower, let lhs_upper) = lhs {
            switch rhs {
            case .floor(let rhs):
                return lhs_lower ~= rhs
            case .range(let rhs_lower, let rhs_upper):
                return (lhs_lower ~= rhs_lower) && (lhs_upper ~= rhs_upper)
            default:
                return false
            }
        }
        if case .none = lhs {
            if case .none = rhs {
                return true
            } else {
                return false
            }
        }
        return false
        
    }
    public static func == (lhs: Subscript.Element.Index, rhs: Subscript.Element.Index) -> Bool {
        if case .constant(let lhs) = lhs {
            if case .constant(let rhs) = rhs {
                return lhs == rhs
            } else {
                return false
            }
        }
        if case .floor(let lhs) = lhs {
            if case .floor(let rhs) = rhs {
                return lhs == rhs
            } else {
                return false
            }
        }
        if case .range(let lhs_lower, let lhs_upper) = lhs {
            if case .range(let rhs_lower, let rhs_upper) = rhs {
                return (lhs_lower == rhs_lower) && (lhs_upper == rhs_upper)
            } else {
                return false
            }
        }
        if case .none = lhs {
            if case .none = rhs {
                return true
            } else {
                return false
            }
        }
        return false
    }
}
