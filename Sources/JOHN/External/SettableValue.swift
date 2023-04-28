//
//  SettableValue.swift
//  
//
//  Created by Alessio Giordano on 07/04/23.
//

import Foundation

internal protocol SettableValue: AnyObject {
    associatedtype Value
    var _sourcePath: Subscript { get set }
    var _wrappedValue: Value { get set }
    
    func set(from result: AnyResult)
}
// MARK: Protocols do not support dynamic dispatching of function calls, so if a default implementation is provided, unless explicitly overriden by a concrete type, it will always be called
// In other words, conditional conformance is not possible
extension SettableValue {
    func set(from result: AnyResult) {
        if let wrappedValue = _wrappedValue as? any SettableWithRawValue {
            // MARK: Assign single values with string extracted from AnyResult
            if let rawValue = result[self._sourcePath]?.text,
            let parsedValue = type(of: wrappedValue).init(rawValue) {
                self._wrappedValue = parsedValue as! Self.Value
            }
        } else if let wrappedValue = _wrappedValue as? any SettableWithCollectionOfRawValues {
            // MARK: Assign collection of values with strings extracted from AnyResult
            if let slice = result[self._sourcePath], let indices = slice.indices {
                self._wrappedValue = type(of: wrappedValue).init(indices.compactMap {
                    return slice[$0]?.text
                }) as! Self.Value
            } else {
                self._wrappedValue = type(of: wrappedValue).init([]) as! Self.Value
            }
        } else if let wrappedValue = _wrappedValue as? any ExpectedResult {
            // MARK: Assign custom set of values extracted from AnyResult
            if let slice = result[self._sourcePath] {
                self._wrappedValue = type(of: wrappedValue).init(from: slice) as! Self.Value
            } else {
                self._wrappedValue = type(of: wrappedValue).init() as! Self.Value
            }
        } else if let wrappedValue = _wrappedValue as? any SettableWithCollectionOfExpectedResults {
            // MARK: Assign a collection of custom set of values extracted from AnyResult
            if let slice = result[self._sourcePath] {
                self._wrappedValue = type(of: wrappedValue).init(type(of: wrappedValue).children(of: slice)) as! Self.Value
            } else {
                self._wrappedValue = type(of: wrappedValue).init([]) as! Self.Value
            }
        } else {
            fatalError("The set(result:_) method can only be called on SettableWithRawValue, SettableWithCollectionOfRawValues or ExpectedResult types")
        }
    }
}
public protocol SettableWithRawValue {
    init?(_: String)
}
public protocol SettableWithCollectionOfRawValues {
    init(_: [String])
}
public protocol SettableWithCollectionOfExpectedResults {
    init(_: [any ExpectedResult])
    static func children(of: AnyResult) -> [any ExpectedResult]
}

// MARK: Conforming primitive LosslessStringConvertible types
extension Bool: SettableWithRawValue {}
extension Character: SettableWithRawValue {}
extension Double: SettableWithRawValue {}
extension Float: SettableWithRawValue {}
#if os(macOS) && arch(x86_64)
/// From the Swift Forums: [Float16] It's supported on Apple Silicon because we have a stable ABI for Float16 on ARM64. It's supported on Windows and Linux because we don't need binary stability on those platforms. But Intel has to define the calling conventions in the x86_64 ABI document and implement them in LLVM before we can make it available in the SDK for macOS on x86.
#else
extension Float16: SettableWithRawValue {}
#endif
#if arch(x86_64)
/// Float80 is available only when running on Intel architectures
extension Float80: SettableWithRawValue {}
#endif
extension Int: SettableWithRawValue {}
extension Int16: SettableWithRawValue {}
extension Int32: SettableWithRawValue {}
extension Int64: SettableWithRawValue {}
extension Int8: SettableWithRawValue {}
extension String: SettableWithRawValue {}
extension Substring: SettableWithRawValue {}
extension UInt: SettableWithRawValue {}
extension UInt16: SettableWithRawValue {}
extension UInt32: SettableWithRawValue {}
extension UInt64: SettableWithRawValue {}
extension UInt8: SettableWithRawValue {}
extension Unicode.Scalar: SettableWithRawValue {}

// MARK: Conforming Optional wrapping SettableWithRawValue
extension Optional: SettableWithRawValue where Wrapped: SettableWithRawValue {
    public init?(_ value: String) {
        self = Wrapped(value)
    }
}

// MARK: Conforming Collection containing SettableWithCollectionOfRawValues
extension Collection where Self: SettableWithCollectionOfRawValues, Self: RangeReplaceableCollection, Self.Element: SettableWithRawValue {
    public init(_ values: [String]) {
        self.init(values.compactMap {
            Element($0)
        })
    }
}
///
extension Array: SettableWithCollectionOfRawValues where Element: SettableWithRawValue {}
extension ArraySlice: SettableWithCollectionOfRawValues where Element: SettableWithRawValue {}
extension ContiguousArray: SettableWithCollectionOfRawValues where Element: SettableWithRawValue {}
///
extension Collection where Self: SettableWithCollectionOfRawValues, Self: SetAlgebra, Self.Element: SettableWithRawValue {
    public init(_ values: [String]) {
        self.init(values.compactMap {
            Element($0)
        })
    }
}
///
extension Set: SettableWithCollectionOfRawValues where Element: SettableWithRawValue {}

// MARK: Conforming Collection containing SettableWithCollectionOfExpectedResults
extension Collection where Self: SettableWithCollectionOfExpectedResults, Self: RangeReplaceableCollection, Self.Element: ExpectedResult {
    public init(_ results: [any ExpectedResult]) {
        self.init(results)
    }
    public static func children(of slice: AnyResult) -> [any ExpectedResult] {
        slice.indices?.compactMap {
            if let child = slice[Subscript.Element(integerLiteral: $0)] {
                return Element(from: child)
            } else { return nil }
        } ?? []
    }
}
///
extension Array: SettableWithCollectionOfExpectedResults where Element: ExpectedResult {}
extension ArraySlice: SettableWithCollectionOfExpectedResults where Element: ExpectedResult {}
extension ContiguousArray: SettableWithCollectionOfExpectedResults where Element: ExpectedResult {}
///
extension Collection where Self: SettableWithCollectionOfExpectedResults, Self: SetAlgebra, Self.Element: ExpectedResult {
    public init(_ results: [any ExpectedResult]) {
        self.init(results)
    }
    public static func children(of slice: AnyResult) -> [any ExpectedResult] {
        slice.indices?.compactMap {
            if let child = slice[Subscript.Element(integerLiteral: $0)] {
                return Element(from: child)
            } else { return nil }
        } ?? []
    }
}
///
extension Set: SettableWithCollectionOfExpectedResults where Element: ExpectedResult {}
