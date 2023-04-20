//
//  AnyResult+Subscript.Element+Key+Pattern.swift
//  
//
//  Created by Alessio Giordano on 05/04/23.
//

import Foundation

extension Subscript.Element.Key {
    public enum Pattern {
        case any, literal(String)
    }
}
extension Subscript.Element.Key.Pattern: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible, Equatable {
    // MARK: ExpressibleByStringLiteral
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        if value.first(where: { $0 != "*" }) == nil {
            self = .any
        } else {
            self = .literal(value)
        }
    }
    // MARK: CustomStringConvertible
    public var description: String {
        switch self {
        case .any:                  return "*"
        case .literal(let value):   return value
        }
    }
    // MARK: Pattern Specificity
    /// Rule: The more non-jolly characters there are, i.e. the closer it is to a constant, the more specific the template is
    /// Example: [*name] is more specific that [*]
    internal var specificity: Int {
        switch self {
        case .any:                  return 0
        case .literal(let value):   return value.count
        }
    }
    // MARK: Equatable Pattern
    public static func == (lhs: Subscript.Element.Key.Pattern, rhs: Subscript.Element.Key.Pattern) -> Bool {
        if case .any = lhs {
            if case .any = rhs {
                return true
            }
        }
        if case .literal(let lhs) = lhs {
            if case .literal(let rhs) = rhs {
                return lhs == rhs
            }
        }
        return false
    }
    /*public static func !== (lhs: Subscript.Element.Key.Pattern, rhs: Subscript.Element.Key.Pattern) -> Bool {
        return !(lhs === rhs)
    }*/
}
extension Array where Element == Subscript.Element.Key.Pattern {
    // MARK: Equatable Array<Pattern>
    // NOTE: == for arrays is automatically synthetized from the base Element
    public static func == (lhs: Array<Element>, rhs: Array<Element>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in lhs.indices {
            if lhs[i] != rhs[i] {
                return false
            }
        }
        return true
    }
    // MARK: String - Pattern Matching
    public static func ~= (lhs: String, rhs: Array<Element>) -> Bool {
        var lhs = lhs, rhs = rhs
        while (!lhs.isEmpty && !rhs.isEmpty) {
            /// Pick the first pattern to test for
            /// It is safe to reset the catch all as after each cycle it is guaranteed to be preceded by a .literal(string) pattern
            var catchAllMode = false
            var match: String?
            repeat {
                if rhs.isEmpty { break }
                switch rhs.removeFirst() {
                case .any:
                    catchAllMode = true
                    match = nil
                case .literal(let string):
                    match = string
                }
            } while (match == nil || match?.count == 0)
            /// Test for the pattern
            if let match {
                repeat {
                    if match.count <= lhs.count {
                        /// Eager match
                        /// If the previous pattern was a catchall [*] and the last pattern is a literal, then the suffix will be tested
                        /// otherwise the test would fail as there are no more patterns to check the renainder of the lhs
                        if rhs.isEmpty && catchAllMode {
                            if lhs.hasSuffix(match) {
                                /// The eager comparison succeded
                                lhs = ""
                                continue
                            } else {
                                return false
                            }
                        }
                        /// Lazy match
                        if lhs.hasPrefix(match) {
                            /// The lazy comparison succeded
                            lhs.removeFirst(match.count)
                            continue
                        } else if catchAllMode == false {
                            /// The comparison failed as an exact match is required (prefix)
                            return false
                        } else {
                            if lhs.count > 0 {
                                lhs.removeFirst()
                            } else {
                                /// The comparison failed as there are no more characters left to try
                                return false
                            }
                        }
                    } else {
                        /// The comparison failed as there aren't enough characters for the prefix to be contained
                        return false
                    }
                } while (catchAllMode)
            }
        }
        /// Either the compared string or the available patterns have been exhausted
        if lhs.isEmpty && rhs.isEmpty {
            /// If both are empty, then we have a perfect match
            return true
        } else if !rhs.isEmpty && rhs.first(where: {
            if case .literal(_) = $0 {
                return true
            } else {
                return false
            }
        }) == nil {
            return true
        } else {
            return false
        }
    }
    public static func ~= (lhs: Array<Element>, rhs: String) -> Bool {
        return rhs ~= lhs
    }
}
