//
//  IOProtocol.swift
//  
//
//  Created by Alessio Giordano on 21/02/23.
//

import Foundation

protocol IOProtocol {
    var wrappedValue: Any { get }
    var text: String? { get }
    var number: Double? { get }
    var boolean: Bool? { get }
    var indices: Range<Int>? { get }
    subscript(_ index: Int) -> (any IOProtocol)? { get }
    var keys: [String] { get }
    subscript(_ key: String) -> (any IOProtocol)? { get }
}
