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
        } else {
            self._wrappedValue = Value([])
        }
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

// MARK: Assign a collection of custom set of values extracted from AnyResult
extension SettableValue where Value: Collection, Value: RangeReplaceableCollection, Value.Element: ExpectedResult {
    func set(from result: AnyResult) {
        if let slice = result[self._sourcePath], let indices = slice.indices {
            self._wrappedValue = Value(indices.compactMap {
                if let child = slice[Subscript.Element(integerLiteral: $0)] {
                    return Value.Element(from: child)
                } else { return nil }
            })
        } else {
            self._wrappedValue = Value([])
        }
    }
}
///
extension SettableValue where Value: Collection, Value: SetAlgebra, Value.Element: ExpectedResult {
    func set(from result: AnyResult) {
        if let slice = result[self._sourcePath], let indices = slice.indices {
            self._wrappedValue = Value(indices.compactMap {
                if let child = slice[Subscript.Element(integerLiteral: $0)] {
                    return Value.Element(from: child)
                } else { return nil }
            })
        } else {
            self._wrappedValue = Value([])
        }
    }
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

// MARK: Conforming Optional wrapping LosslessStringConvertible
extension Optional: SettableWithRawValue where Wrapped: SettableWithRawValue {
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
