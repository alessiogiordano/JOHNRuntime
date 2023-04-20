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
extension SettableValue {
    func set(from result: AnyResult) {
        fatalError("The set(result:_, path:_) method can only be called on LosslessStringConvertible, Collection or ExpectedResult types")
    }
}
public protocol SettableWithRawValue {
    init?(_: String)
}
public protocol SettableWithCollectionOfRawValues {
    init(_: [String])
}

// MARK: Assign single values with string extracted from AnyResult
extension SettableValue where Value: SettableWithRawValue {
    func set(rawValue: String) {
        self._wrappedValue = Value(rawValue) ?? _wrappedValue // It is only run once by the initializer anyway
    }
    func set(from result: AnyResult) {
        if let rawValue = result[self._sourcePath]?.text {
            self.set(rawValue: rawValue)
        }
    }
}

// MARK: Assign collection of values with strings extracted from AnyResult
extension SettableValue where Value: SettableWithCollectionOfRawValues {
    func set(from result: AnyResult) {
        if let slice = result[self._sourcePath], let indices = slice.indices {
            self._wrappedValue = Value(indices.compactMap {
                return slice[$0]?.text
            })
        }
        self._wrappedValue = Value([])
    }
}

// MARK: Assign custom set of values extracted from AnyResult
extension SettableValue where Value: ExpectedResult {
    func set(from result: AnyResult) {
        if let slice = result[self._sourcePath] {
            self._wrappedValue = Value(from: slice)
        } else {
            self._wrappedValue = .init()
        }
    }
}

// MARK: Conforming primitive LosslessStringConvertible types
extension Bool: SettableWithRawValue {}
extension Character: SettableWithRawValue {}
extension Double: SettableWithRawValue {}
extension Float: SettableWithRawValue {}
extension Float16: SettableWithRawValue {}
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

// MARK: Conforming Optional wrapping LosslessStringConvertible
extension Optional: SettableWithRawValue where Wrapped: LosslessStringConvertible {
    public init?(_ value: String) {
        self = Wrapped(value)
    }
}

// MARK: Conforming Collection containing LosslessStringConvertible
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
