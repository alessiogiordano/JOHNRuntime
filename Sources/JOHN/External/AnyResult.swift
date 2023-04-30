//
//  AnyResult.swift
//  
//
//  Created by Alessio Giordano on 04/04/23.
//

import Foundation

public enum AnyResultError: Error {
    case emptyResultSet, requestedPathComponentIsPlaceholder
}

public struct AnyResult: IOProtocol, Sequence {
    @Source var sources: [(any IOProtocol)?]
            let path: Path
            let wrappedPayload: (any IOProtocol)?
    
    typealias Path = (map: [Subscript: Result], inherited: Subscript)
    
    @propertyWrapper
    class Source {
        internal let outputs: [(any IOProtocol)?]
        public var wrappedValue: [(any IOProtocol)?] { outputs }
        public var projectedValue: Source { return self }
        init(wrappedValue: [(any IOProtocol)?]) {
            self.outputs = wrappedValue
        }
        public subscript(variable: String) -> (any IOProtocol)? {
            if let resolvedValue = try? Variable(string: variable).resolve(with: outputs) {
                return resolvedValue
            } else if let textValue = try? Variable.substitute(outputs: outputs, in: variable) {
                return IOPayload(text: textValue)
            } else {
                return nil
            }
        }
    }
    
    /// Initializers
    
    internal init(sources: Source, path: Path, wrappedPayload: (any IOProtocol)?) {
        self._sources = sources
        self.path = path
        self.wrappedPayload = wrappedPayload
        self.keys = wrappedPayload?.keys ?? []
        self.indices = wrappedPayload?.indices
    }
    /// The empty result can be used when errors cannot be thrown or optionals are not allowed, to avoid keeping a reference to the output array when nothing can be read from it
    internal static var emptyResult: Self {
        .init(sources: .init(wrappedValue: []), path: ([:], .init()), wrappedPayload: nil)
    }
    
    internal init(sliceOf result: AnyResult, at pathComponent: Subscript.Element?) throws {
        let currentPath: Subscript
        
        /// A nil path component is allowed when initializing the root of a AnyResult, otherwise just return the current result
        if let pathComponent {
            /// Placeholder inputs would make it impossible to resolve placeholders in the subscripts and therefore lead to undefined behavior
            if pathComponent.isPlaceholder {
                throw AnyResultError.requestedPathComponentIsPlaceholder
            }
            currentPath = result.path.inherited.appending(pathComponent)
        } else if result.path.inherited.isEmpty {
            /// Initializing root
            currentPath = .init()
        } else {
            self = result
            return
        }
        
        self._sources = result._sources
        
        /// Advancing the subscript can only happen element-by-element, as the wrappedPayload is either the directly specified subscript or the immediate child of the previous wrappedPayload in case it was an object or array structure directly ported from the IOProtocol of the pipeline. Otherwise, inconsistent results would be obtained between single element subscripts and multiple element subscripts
        
        // MARK: Step Zero - Gather immediate key and integer subscripts
        var immediateKeys: Set<String> = .init()
        var lowerBound: Int? = nil
        var upperBound: Int? = nil
        
        /// This closure is safe to call only when the nestedSubscript is a child of the currentPath, meaning it has at least n+1 elements
        let extractImmediateSubscripts: (Subscript) -> () = { nestedSubscript in
            /// Prevent accessing the next component when it is not available, for example when a string subscript may contain a syntax error like a missing closing bracket ]
            if currentPath.count >= nestedSubscript.count { return }
            let immediateSubscript = nestedSubscript[currentPath.count]
            if case .key(let key) = immediateSubscript, !immediateSubscript.isPlaceholder {
                immediateKeys.insert(key.description)
            }
            if case .index(let index) = immediateSubscript, let range = index.rawValue {
                if let lowerBound, lowerBound < range.lowerBound {}
                  else { lowerBound = range.lowerBound }
                if let upperBound, upperBound > range.upperBound {}
                  else { upperBound = range.upperBound }
            }
        }
        
        // MARK: Step one - Advance the result map
        /// Next the result map is advanced
        var exactMatch: (subscript: Subscript, string: String)? = nil
        var subscriptMap: [Subscript: Result] = [:]
        for (internalSubscript, nestedResult) in result.path.map {
            /// Resolve bounds if necessary
            let internalSubscript = internalSubscript.resolvingBounds(with: result.sources)
            /// Only subscripts that match the currentPath will be retained and flattened, while the others will be dropped
            if currentPath ~= internalSubscript {
                if currentPath.count == internalSubscript.count {
                    // Not enough: I need to check that a constant value corresponds to it, otherwise how is it different from a string of several subscript components?
                    var nestedResult: Result? = nestedResult
                    while nestedResult != nil {
                        switch nestedResult {
                        case .conditional(let condition):
                            /// Conditionals are neither constant or nested, they must be resolved to contiunue. Doing so does not alter the currentPath, meaning the loop can be self-contained here
                            do {
                                try nestedResult!.verifyAssertion(with: result._sources.outputs, mappingPlaceholdersFrom: internalSubscript, toValuesOf: currentPath)
                                nestedResult = condition.result
                                continue
                            } catch {
                                nestedResult = condition.catch
                                continue
                            }
                        case .constant(let string):
                            /// If the currentPath is the prefix of internalSubscript, then if they have the same component count and the corresponding result is a constant the two match perfectly
                            if let previous = exactMatch {
                                /// Only if the specificity of the exact match is improved, then duplicate matches will be swapped
                                /// The comparison check is designed so the most specific will win the "less than" comparator
                                if previous.subscript > internalSubscript {
                                    exactMatch = (internalSubscript, string)
                                }
                                /// Of course if no match has been found yet, the specificity does not matter
                            } else { exactMatch = (internalSubscript, string) }
                            nestedResult = nil
                            continue
                        case .nested(let dictionary):
                            /// If the match contains more than one element, then it is a child match and the children must be flattened
                            dictionary.forEach { nestedSubscript, nestedResult in
                                let flattenedSubscript = internalSubscript.appending(contentsOf: nestedSubscript)
                                extractImmediateSubscripts(flattenedSubscript)
                                subscriptMap[flattenedSubscript] = nestedResult
                            }
                            nestedResult = nil
                            continue
                        case .none:
                            continue
                        }
                    }
                } else {
                    /// If the match contains more than one element, then it is a child match
                    extractImmediateSubscripts(internalSubscript)
                    subscriptMap[internalSubscript] = nestedResult
                }
            }
        }
        self.path = (map: subscriptMap, inherited: currentPath)
        
        // MARK: Step Two - Gather the wrappedPayload
        let wrappedPayload: (any IOProtocol)?
        if let exactMatch,
           let sourceSubscript = try? exactMatch.subscript.resolvePlaceholders(with: currentPath, into: exactMatch.string),
           let sourcePayload = result._sources[sourceSubscript] {
            wrappedPayload = sourcePayload
        } else {
            /// The provided path component is parsed to subscript the previous wrapped payload for child nodes
            switch pathComponent {
            case .key(let key):
                if case .constant(let constant) = key {
                    /// Found dictionary subscript
                    wrappedPayload = result.wrappedPayload?[constant]
                } else { wrappedPayload = nil }
            case .index(let index):
                if case .constant(let constant) = index {
                    /// Found array subscript
                    wrappedPayload = result.wrappedPayload?[constant]
                } else { wrappedPayload = nil }
            default: wrappedPayload = nil
            }
        }
        self.wrappedPayload = wrappedPayload
        
        // MARK: Step Three - Set key and integer indices
        /// Set the keys to the union of the natural keys of the payload and the immediate keys of the available result subscripts, if not placeholders
        self.keys = Array(Set<String>(wrappedPayload?.keys ?? []).union(immediateKeys))
        /// Set the bounds to the largest possible set
        if let payloadLowerBound = wrappedPayload?.indices?.lowerBound {
            if let immediateLowerBound = lowerBound {
                if payloadLowerBound < immediateLowerBound {
                    lowerBound = payloadLowerBound
                }
            } else {
                lowerBound = payloadLowerBound
            }
        }
        if let payloadUpperBound = wrappedPayload?.indices?.upperBound {
            if let immediateUpperBound = upperBound {
                if payloadUpperBound > immediateUpperBound {
                    upperBound = payloadUpperBound
                }
            } else {
                upperBound = payloadUpperBound
            }
        }
        if let lowerBound, let upperBound {
            self.indices = lowerBound..<upperBound
        } else {
            self.indices = nil
        }
        
        // MARK: Step Four - Verify that the result slice contains any elements
        /// If both a natural wrappedPayload and the result map are empty, then no value can be accessed from this slice and it would be a waste of memory to keep a reference to the whole output array
        if wrappedPayload == nil && path.map.isEmpty {
            throw AnyResultError.emptyResultSet
        }
    }
    
    internal init(sliceOf result: AnyResult, at path: Subscript) throws {
        /// Multi-level slicing is done as an iterative single-level slicing
        if path.isEmpty {
            self = result
            return
        }
        var intermediate: Self? = result
        for component in path {
            if intermediate == nil {
                throw AnyResultError.emptyResultSet
            } else {
                intermediate = try? .init(sliceOf: intermediate!, at: component)
            }
        }
        if let intermediate {
            self = intermediate
        } else {
            throw AnyResultError.emptyResultSet
        }
    }
    
    internal init(rootOf outputs: [(any IOProtocol)?], via map: Result) {
        self.init(rootOf: Source.init(wrappedValue: outputs), via: map)
    }
    internal init(rootOf sources: Source, via map: Result) {
        do {
            /// The root initializer is equivalent to slicing with the empty subscript and no inherited path
            let result = AnyResult(sources: sources, path: ([Subscript(): map], Subscript()), wrappedPayload: nil)
            try self.init(sliceOf: result, at: nil)
        } catch {
            self = .emptyResult
        }
    }
    
    // MARK: IOProtocol Properties
    /// Single Values are not affected by the result map
    internal var wrappedValue: Any { wrappedPayload?.wrappedValue as Any }
    public var text: String? { wrappedPayload?.text }
    public var number: Double? { wrappedPayload?.number }
    public var boolean: Bool? { wrappedPayload?.boolean }
    /// The indices represent the largest known range where the caller can possibly find non nil values
    public let indices: Range<Int>?
    internal subscript(index: Int) -> (IOProtocol)? {
        try? Self(sliceOf: self, at: Subscript.Element(integerLiteral: index))
    }
    /// The subscript result map is added to the natural key map of the wrapped dictionary (if any)
    /// The string subscript takes precedence over the ExpressibleByStringLiteral subscript, but externally only the latter one is available
    public let keys: [String]
    internal subscript(key: String) -> (IOProtocol)? {
        try? Self(sliceOf: self, at: Subscript.Element(stringLiteral: key))
    }
    // MARK: Sequence protocol
    public struct Iterator: IteratorProtocol {
        var currentRangeIndex: Int
        let source: AnyResult
        public typealias Element = AnyResult
        public mutating func next() -> AnyResult? {
            defer { self.currentRangeIndex += 1 }
            if let index = source.indices?[self.currentRangeIndex] {
                return source[.init(integerLiteral: index)]
            } else {
                return nil
            }
        }
        
    }
    public func makeIterator() -> Iterator {
        Iterator(currentRangeIndex: self.indices?.first ?? 0, source: self)
    }
    // MARK: Subscript
    /// Since each level of the hierarchy introduces an optional, the Subscript variadic syntax coalesces all of it in a single subscript that yields a single optional
    public subscript(path: Subscript.Element...) -> Self? {
        self[Subscript(rawValue: path)]
    }
    /// Direct usage of the subscript is made by the ExpectedResult type-safe accessor
    public subscript(path: Subscript) -> Self? {
        try? Self(sliceOf: self, at: path)
    }
}
