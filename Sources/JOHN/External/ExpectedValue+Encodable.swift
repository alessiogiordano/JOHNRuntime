//
//  ExpectedValue+Encodable.swift
//  
//
//  Created by Alessio Giordano on 27/04/23.
//

import Foundation

extension ExpectedValue: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}
// MARK: Decodable conformance is not possible as it must be declared via a required initializer in the class definition itself, and doing so would prevent wrapping values that are not codable (as many ExpectedResults would be)
// And even if I tried to use class inheritance for that, I would not be able to set the wrappedPath from the decoder in super.init()
/// Initializer requirement 'init(from:)' can only be satisfied by a 'required' initializer in the definition of non-final class 'ExpectedValue<Value>'
/*extension ExpectedValue: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        self._wrappedValue = try .init(from: decoder)
    }
}*/
