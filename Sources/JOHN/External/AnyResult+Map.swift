//
//  AnyResult+Map.swift
//  
//
//  Created by Alessio Giordano on 31/03/23.
//

import Foundation

extension AnyResult {
    public class Map {
        internal let outputs: [(any IOProtocol)?]
        internal let subscripts: [Subscript: String]
        
        // MARK: Initializer
        internal init(_ outputs: [(any IOProtocol)?], result: Result) {
            self.outputs = outputs
            self.subscripts = result.subscripts(verifying: outputs)
        }
        
        // MARK: Accessing mapped result
        internal subscript(externalSubscript: Subscript) -> (any IOProtocol)? {
            guard let match = internalSubscript(from: externalSubscript) else { return nil }
            if let resolvedValue = try? Variable(string: match).resolve(with: outputs) {
                return resolvedValue
            } else if let textValue = try? Variable.substitute(outputs: outputs, in: match) {
                return IOPayload(text: textValue)
            } else {
                return nil
            }
        }
        
        // MARK: External -> Internal subscript mapping
        internal func internalSubscript(from externalSubscript: String) -> String? {
            return internalSubscript(from: Subscript.init(stringLiteral: externalSubscript))
        }
        internal func internalSubscript(from externalSubscript: Subscript) -> String? {
            /// Check that no unresolved placeholders are present in the input
            guard externalSubscript.placeholderCount == 0 else { return nil }
            /// Internal <-> External lookup
            var bestMatch: Subscript? = nil
            self.subscripts.keys.forEach {
                if externalSubscript ~= $0 {
                    if let previous = bestMatch {
                        if previous > $0 {
                            bestMatch = $0
                        }
                    } else { bestMatch = $0 }
                }
            }
            guard let bestMatch else { return nil }
            /// Internal <-> External mapping was found
            guard let internalSubscript = self.subscripts[bestMatch] else { return nil }
            return try? bestMatch.resolvePlaceholders(with: externalSubscript, into: internalSubscript)
        }
    }
}
