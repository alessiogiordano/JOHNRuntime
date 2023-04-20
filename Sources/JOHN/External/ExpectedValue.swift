//
//  ExpectedValue.swift
//  
//
//  Created by Alessio Giordano on 06/04/23.
//

import Foundation

@propertyWrapper
public class ExpectedValue<Value>: SettableValue {
    internal var _sourcePath: Subscript
    internal var _wrappedValue: Value
    
    public var wrappedValue: Value { _wrappedValue }
    
    private init(_wrappedValue: Value, _sourcePath: Subscript) {
        self._wrappedValue = _wrappedValue
        self._sourcePath = _sourcePath
    }
}

// MARK: @ExpectedValue("key") var value: Int = 0
public extension ExpectedValue where Value: SettableWithRawValue {
    convenience init(wrappedValue: Value, _ path: String) {
        self.init(_wrappedValue: wrappedValue, _sourcePath: .init(stringLiteral: path))
    }
    convenience init(wrappedValue: Value, _ path: Subscript) {
        self.init(_wrappedValue: wrappedValue, _sourcePath: path)
    }
}

// MARK: @ExpectedValue("key") var value: Int?
public extension ExpectedValue where Value: SettableWithRawValue, Value: ExpressibleByNilLiteral {
    convenience init(_ path: String) {
        self.init(Subscript(stringLiteral: path))
    }
    convenience init(_ path: Subscript) {
        self.init(_wrappedValue: nil, _sourcePath: path)
    }
}

// MARK: @ExpectedValue("key") var value: [Int]
// MARK: @ExpectedValue("key") var value: Set<Int>
public extension ExpectedValue where Value: SettableWithCollectionOfRawValues {
    convenience init(wrappedValue: Value = .init([]), _ path: String) {
        self.init(wrappedValue: wrappedValue, Subscript(stringLiteral: path))
    }
    convenience init(wrappedValue: Value = .init([]), _ path: Subscript) {
        self.init(_wrappedValue: wrappedValue, _sourcePath: path)
    }
}

// MARK: @ExpectedValue("key") var value: CustomType where CustomType: ExpectedResult
public extension ExpectedValue where Value: ExpectedResult {
    convenience init(wrappedValue: Value = .init(), _ path: String) {
        self.init(wrappedValue: wrappedValue, Subscript(stringLiteral: path))
    }
    convenience init(wrappedValue: Value = .init(), _ path: Subscript) {
        self.init(_wrappedValue: wrappedValue, _sourcePath: path)
    }
}
