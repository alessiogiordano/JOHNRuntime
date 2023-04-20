//
//  Assertion.swift
//  
//
//  Created by Alessio Giordano on 22/02/23.
//

import Foundation

struct Assertion: Codable, Equatable {
    enum Error: Swift.Error { case assertionFailed }
    /// Valid assertions
    let exists: Bool? /// Assert that all variables in the provided string are resolved
    let contained: [String]? /// Assert that the resolved string is contained in the array
}

extension Stage {
    func verifyAssertion(in context: Execution) throws {
        guard let assertions = assert else { return }
        for (variable, assertion) in assertions {
            let resolvedValue = try? Variable.substitute(outputs: context.outputs, in: variable)
            /// "Exists" Assertion
            if let exists = assertion.exists {
                if resolvedValue == nil && exists == true || resolvedValue != nil && exists == false {
                    // MARK: didFailExistsAssertion Event
                    context.delegate?.debug(didFailExistsAssertion: variable, assertion: exists)
                    throw Assertion.Error.assertionFailed
                }
                // MARK: didPassExistsAssertion Event
                context.delegate?.debug(didPassExistsAssertion: variable, assertion: exists)
            }
            /// "Contained" Assertion
            if let matches = assertion.contained {
                guard let resolvedValue else {
                    // MARK: didFailContainedAssertion Event
                    context.delegate?.debug(didFailContainedAssertion: variable, assertion: matches)
                    throw Assertion.Error.assertionFailed }
                if matches.first(where: { $0 == resolvedValue }) == nil {
                    // MARK: didFailContainedAssertion Event
                    context.delegate?.debug(didFailContainedAssertion: variable, assertion: matches)
                    throw Assertion.Error.assertionFailed
                }
                // MARK: didPassContainedAssertion Event
                context.delegate?.debug(didPassContainedAssertion: variable, assertion: matches)
            }
        }
    }
}

extension Result {
    func verifyAssertion(with variables: [(any IOProtocol)?]) throws {
        guard case .conditional(let result) = self else { return }
        guard let assertions = result.assert else { return }
        for (variable, assertion) in assertions {
            let resolvedValue = try? Variable.substitute(outputs: variables, in: variable)
            /// "Exists" Assertion
            if let exists = assertion.exists {
                if resolvedValue == nil && exists == true || resolvedValue != nil && exists == false {
                    throw Assertion.Error.assertionFailed
                }
            }
            /// "Contained" Assertion
            if let matches = assertion.contained {
                guard let resolvedValue else { throw Assertion.Error.assertionFailed }
                if matches.first(where: { $0 == resolvedValue }) == nil {
                    throw Assertion.Error.assertionFailed
                }
            }
        }
    }
}
