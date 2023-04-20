//
//  JOHN+Group.swift
//  
//
//  Created by Alessio Giordano on 17/04/23.
//

import Foundation

extension JOHN {
    public class Group {
        /// Options
        let defaults: JOHN.Options
        let sharing: Set<Share>
        public enum Share: CaseIterable {
            case cookies, requests
        }
        /// Context
        let context: Execution
        /// Initializer
        required init(defaults: JOHN.Options = .none, sharing: Set<Share> = .init(Share.allCases)) throws {
            self.context = try .init(with: .none)
            self.defaults = defaults
            self.sharing = sharing
        }
        /// Convenience initializers
        static func defaults(_ defaults: JOHN.Options) throws -> Self {
            return try self.init(defaults: defaults)
        }
        static func sharing(_ sharing: Share...) throws -> Self {
            return try self.init(sharing: .init(sharing))
        }
        /// Prepare context
        func prepareForExecution(with requestOptions: JOHN.Options) async throws {
            let options = requestOptions.merging(options: defaults)
            try context.update(with: options)
            if !sharing.contains(.cookies) {
                context.cookies = [:]
            }
            if !sharing.contains(.requests) {
                try await context.executeDeferedRequests()
                context.identifiedResponses = [:]
                context.uniqueDeferedIdentifiers.removeAll()
            }
        }
        func concludeExecution() async throws {
            try await context.executeDeferedRequests()
        }
    }
}

public extension JOHN {
    static func withExecutionGroup(defaults: JOHN.Options = .none, sharing: Set<Group.Share> = .init(Group.Share.allCases), body: ((Group) async throws -> ())) async throws {
        try await body(.init(defaults: defaults, sharing: sharing))
    }
}

public extension JOHN.Group {
    func execute(_ plugin: JOHN, with options: JOHN.Options = .none) async throws -> AnyResult {
        try await plugin.execute(on: self, with: options)
    }
}
