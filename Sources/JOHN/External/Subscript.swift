//
//  Subscript.swift
//  
//
//  Created by Alessio Giordano on 04/04/23.
//

import Foundation

public struct Subscript: Collection, RawRepresentable, Comparable, Equatable, CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Hashable {
    internal let components: [Subscript.Element]
    
    internal let specificity: Specificity
    internal var placeholderCount: Int { specificity.placeholderCount }
    internal struct Specificity {
        let map: [(index: Int, value: Int)]
        let placeholderCount: Int
        init(components: [Subscript.Element]) {
            let map = components.indices.map {
                return (index: $0, value: components[$0].specificity)
            }
            self.map = map
            self.placeholderCount = components.reduce(0) { result, element in
                element.isPlaceholder ? result + 1 : result
            }
        }
    }
    
    // MARK: Resolve integer subscript variables
    internal static func resolveBoundsIfNecessary(components: [Subscript.Element], with outputs: [(any IOProtocol)?]) -> [Subscript.Element] {
        return components.map {
            switch $0 {
            case .index(let index): return .index(index.resolveIfNecessary(from: outputs))
            default:                return $0
            }
        }
    }
    
    // MARK: Expressible as String
    /// Example: "first[second][third]"
    public typealias StringLiteralType = String
    public static func parse(_ string: String) -> Self {
        self.init(stringLiteral: string)
    }
    public init(stringLiteral value: String) {
        self.init(stringLiteral: value, resolvingBoundsWith: nil)
    }
    internal init(stringLiteral value: String, resolvingBoundsWith outputs: [(any IOProtocol)?]?) {
        var components = (try? Parser.components(from: value)) ?? []
        if let outputs {
            components = Self.resolveBoundsIfNecessary(components: components, with: outputs)
        }
        self.components = components
        self.specificity = Specificity(components: components)
        self._sourceStringLiteral = value
    }
    internal let _sourceStringLiteral: String?
    public var description: String {
        return _sourceStringLiteral ?? "\(self.components.first?.description ?? "")\(self.components.dropFirst().flatMap { $0.description(withParentheses: true) })"
    }
    internal struct Parser {
        enum State: Equatable {
            case lookingForOpen, lookingForClose(count: Int)
        }
        enum ParsingError: Error {
            case unpairedParentheses
        }
        static func components(from stringLiteral: String) throws -> [Subscript.Element] {
            var components: [Subscript.Element] = []
            var buffer: String = ""
            var state: State = .lookingForOpen
            let flush: () -> () = {
                if !buffer.isEmpty {
                    components.append(.init(stringLiteral: buffer))
                    buffer = ""
                }
            }
            for character in stringLiteral {
                switch state {
                case .lookingForOpen:
                    if character == "[" {
                        flush()
                        state = .lookingForClose(count: 0)
                        continue
                    }
                case .lookingForClose(let count):
                    if character == "[" {
                        state = .lookingForClose(count: count + 1)
                        /// Current character will be appended to buffer
                    } else if character == "]" {
                        if count < 1 {
                            flush()
                            state = .lookingForOpen
                            continue
                        } else {
                            state = .lookingForClose(count: count + 1)
                            /// Current character will be appended to buffer
                        }
                    }
                }
                buffer.append(character)
            }
            if components.count == 0 && state == .lookingForOpen {
                flush()
            }
            guard state == .lookingForOpen else { throw ParsingError.unpairedParentheses }
            return components
        }
    }
    
    // MARK: RawRepresentable as [Subscript.Element]
    /// Struct  <-- ArrayLiteral Conversion
    public typealias RawValue = Swift.Array<Subscript.Element>
    public init(rawValue: RawValue = .init()) {
        self.init(rawValue: rawValue, resolvingBoundsWith: nil)
    }
    internal init(rawValue: RawValue, resolvingBoundsWith outputs: [(any IOProtocol)?]?) {
        if let outputs {
            self.components = Self.resolveBoundsIfNecessary(components: rawValue, with: outputs)
        } else {
            self.components = rawValue
        }
        self.specificity = Specificity(components: self.components)
        self._sourceStringLiteral = nil
    }
    /// Struct --> ArrayLiteral Conversion
    public var rawValue: RawValue { components }
    
    // MARK: Comparison
    /// Simple comparison check picks the component with the deepest first jolly as the most specific one
    public static func < (lhs: Subscript, rhs: Subscript) -> Bool {
        /// The deepest the key path, the more specific it is, regardless of placeholders
        if lhs.count > rhs.count { return true }
        if lhs.count < rhs.count { return false }
        /// If both sides are of the same number of components, the less placeholders are present, the more specific it is
        if lhs.specificity.placeholderCount < rhs.specificity.placeholderCount { return true }
        if lhs.specificity.placeholderCount > rhs.specificity.placeholderCount { return false }
        /// If both sides have the same exact number of placeholders, the one that feature them last is the most specific
        /// That is, the one that features the highest specificity at the start (constant values) represents way fewer items
        for index in lhs.specificity.map.indices {
            if lhs.specificity.map[index].value > rhs.specificity.map[index].value { return true }
            if lhs.specificity.map[index].value < rhs.specificity.map[index].value { return false }
        }
        return false
    }
    // MARK: Matching
    /// Simple equivalence check requires that only non jolly subscripts match
    public static func ~= (lhs: Subscript, rhs: Subscript) -> Bool {
        guard lhs.components.count == rhs.components.count else { return false }
        for index in lhs.components.indices {
            guard lhs.components[index] ~= rhs.components[index]
            else { return false }
        }
        return true
    }
    // MARK: Equivalence
    /// Strict equivalence requires exact equivalence of each component of the array
    public static func == (lhs: Subscript, rhs: Subscript) -> Bool {
        guard lhs.components.count == rhs.components.count else { return false }
        for index in lhs.components.indices {
            guard lhs.components[index] == rhs.components[index]
            else { return false }
        }
        return true
    }
    // MARK: Sequence Protocol
    public typealias Iterator = RawValue.Iterator
    public func makeIterator() -> RawValue.Iterator {
        self.components.makeIterator()
    }
    // MARK: DropFirstSequence
    public func dropFirst(_ k: Int = 1) -> Self {
        .init(rawValue: Swift.Array(self.components.dropFirst(k)))
    }
    // MARK: DropWhileSequence
    public func drop(while predicate: (RawValue.Element) throws -> Bool) rethrows -> Self {
        try .init(rawValue: Swift.Array(self.components.drop(while: predicate)))
    }
    // MARK: DropLastSequence
    public func dropLast(_ k: Int = 1) -> Self {
        .init(rawValue: Swift.Array(self.components.dropLast(k)))
    }
    // MARK: PrefixSequence
    public func prefix(_ maxLength: Int) -> Self {
        .init(rawValue: Swift.Array(self.components.prefix(maxLength)))
    }
    public func prefix(while predicate: (RawValue.Element) throws -> Bool) rethrows -> Self {
        try .init(rawValue: Swift.Array(self.components.prefix(while: predicate)))
    }
    public func suffix(_ maxLength: Int) -> Self {
        .init(rawValue: Swift.Array(self.components.suffix(maxLength)))
    }
    // MARK: Collection Protocol
    public typealias Index = RawValue.Index
    public var startIndex: Index {
        self.components.startIndex
    }
    public var endIndex: Index {
        self.components.endIndex
    }
    public subscript(position: RawValue.Index) -> RawValue.Element {
        self.components[position]
    }
    public func index(after i: RawValue.Index) -> RawValue.Index {
        self.components.index(after: i)
    }
    public func appending(_ newElement: RawValue.Element) -> Self {
        .init(rawValue: [self.components, [newElement]].flatMap { $0 } )
    }
    public func appending(contentsOf newElements: RawValue) -> Self {
        .init(rawValue: [self.components, newElements].flatMap { $0 } )
    }
    public func appending(contentsOf newElements: Self) -> Self {
        .init(rawValue: [self.components, newElements.components].flatMap { $0 } )
    }
    // MARK: Hashable Protocol
    public var hashValue: Int {
        self.description.hashValue
    }
    public func hash(into hasher: inout Hasher) {
        self.description.hash(into: &hasher)
    }
    
    
    // MARK: Jolly Subscript.Element Resolution
    public enum ResolutionError: Error {
        case overflow, unresolved
    }
    internal func listResolvedPlaceholders(with source: Self) throws -> [String] {
        /// It used to be easy to replace placeholders when anything went. Now I need to implement the equatable protocol
        try self.components.indices.compactMap {
            if self.components[$0].isPlaceholder {
                guard source.components.count > $0          else { throw ResolutionError.overflow }
                guard !source.components[$0].isPlaceholder  else { throw ResolutionError.unresolved }
                return source.components[$0].description
            } else { return nil }
        }
    }
    internal func resolvePlaceholders(with source: Self, into destination: String) throws -> String {
        var variables: [String] = try self.listResolvedPlaceholders(with: source).reversed()
        let destination = destination.split(separator: "[*]")
        return try destination.dropFirst().map {
            guard variables.count > 0 else { throw ResolutionError.overflow }
            let value = variables.remove(at: 0)
            return "\($0)[\(value)]"
        }.joined().appending(destination.first ?? "")
    }
}

/*
extension Optional where Wrapped == Subscript {
    public static func == (lhs: Subscript?, rhs: Subscript?) -> Bool {
        if let lhs {
            if let rhs {
                return lhs == rhs
            } else  {
                return lhs.isEmpty
            }
        } else {
            if let rhs {
                return rhs.isEmpty
            } else {
                return true
            }
        }
    }
}
*/
