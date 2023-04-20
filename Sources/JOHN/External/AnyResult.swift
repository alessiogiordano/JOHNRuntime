//
//  AnyResult.swift
//  
//
//  Created by Alessio Giordano on 04/04/23.
//

import Foundation

public enum AnyResultError: Error {
    case emptyResultSet
}

public struct AnyResult: IOProtocol, Sequence {
    let inheritedPath: Subscript
    let resultMap: AnyResult.Map
    let wrappedPayload: (any IOProtocol)?
    
    // MARK: Private initializer
    private init(inheritedPath: Subscript, resultMap: AnyResult.Map, wrappedPayload: (any IOProtocol)? = nil) throws {
        self.wrappedPayload = wrappedPayload
        self.resultMap = resultMap
        self.inheritedPath = inheritedPath
        /// Guaranteed that the difference is at least 1, and that subscripting N+1 will never fail
        var keys: Set<String> = .init(wrappedPayload?.keys ?? [])
        var catchAllSubscriptAvailable = false
        var lowerBound: Int? = wrappedPayload?.indices?.lowerBound
        var upperBound: Int? = wrappedPayload?.indices?.upperBound
        resultMap.subscripts.filter { $0.key.count > inheritedPath.count }
                  .forEach {
                      let keyPath: Subscript = $0.key
                      /// I drop as many subscripts as the accumulated path of the slice and check for their to match
                      if keyPath.prefix(inheritedPath.count) == inheritedPath {
                          if keyPath[inheritedPath.count].isPlaceholder {
                              catchAllSubscriptAvailable = true
                          } else if case .key(let key) = keyPath[inheritedPath.count] {
                              keys.insert(key.description)
                          } else if case .index(let index) = keyPath[inheritedPath.count], let range = index.rawValue {
                              if let lowerBound, lowerBound < range.lowerBound {}
                                else { lowerBound = range.lowerBound }
                              if let upperBound, upperBound > range.upperBound {}
                                else { upperBound = range.upperBound }
                          }
                      }
                  }
        let indices: Range<Int>?
        if let lowerBound, let upperBound {
            indices = lowerBound..<upperBound
        } else {
            indices = nil
        }
        if wrappedPayload == nil && keys.isEmpty && indices == nil && !catchAllSubscriptAvailable {
            throw AnyResultError.emptyResultSet
        }
        self.keys = Array(keys)
        self.indices = indices
    }
    // MARK: Module internal initializers
    internal init?(sliceOf resultMap: AnyResult.Map, at path: Subscript, wrapping payload: (any IOProtocol)? = nil) {
        try? self.init(inheritedPath: path, resultMap: resultMap, wrappedPayload: resultMap[path] ?? payload)
    }
    internal init(rootOf resultMap: AnyResult.Map) {
        do {
            try self.init(inheritedPath: "", resultMap: resultMap, wrappedPayload: resultMap[""])
        } catch {
            self.init()
        }
    }
    internal init() {
        self.wrappedPayload = nil
        self.resultMap = .init([], result: .nested([:]))
        self.inheritedPath = ""
        self.indices = nil
        self.keys = []
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
        let absolutePath = inheritedPath.appending(.init(integerLiteral: index))
        return Self(sliceOf: resultMap, at: absolutePath, wrapping: wrappedPayload?[index])
    }
    /// The subscript result map is added to the natural key map of the wrapped dictionary (if any)
    /// The string subscript takes precedence over the ExpressibleByStringLiteral subscript, but externally only the latter one is available
    public let keys: [String]
    internal subscript(key: String) -> (IOProtocol)? {
        let absolutePath = inheritedPath.appending(.init(stringLiteral: key))
        return Self(sliceOf: resultMap, at: absolutePath, wrapping: wrappedPayload?[key])
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
        var result: Self? = self
        if path.isEmpty { return self }
        for component in path {
            switch component {
            case .key(let key):
                if case .constant(let constant) = key {
                    /// Found dictionary subscript
                    result = result?[constant] as? Self
                }
            case .index(let index):
                if case .constant(let constant) = index {
                    /// Found array subscript
                    result = result?[constant] as? Self
                }
            default: break
            }
            if result == nil { return nil }
        }
        return result
    }
}
