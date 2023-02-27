//
//  Stage+Merger.swift
//  
//
//  Created by Alessio Giordano on 22/02/23.
//

import Foundation

struct Merger: Codable, Equatable {
    enum Error: Swift.Error { case notRequested, outOfBounds }
    ///
    let stage: [Int]?
    /// Variable substitution policy
    let `default`: Policy?
    let override: [String: Policy]
    enum Policy: String, Codable { case first, keep, append, replace, last, none }
}

extension Stage {
    func merge(from variables: [(any IOProtocol)?]) throws -> IOPagination? {
        guard let merger = self.merge,
              let stage = merger.stage,
              stage.isEmpty == false else { throw Merger.Error.notRequested }
        var output = IOPagination(wrappedPages: [], mergingPolicy: merger)
        try stage.forEach {
            guard variables.indices.contains($0) else { throw Merger.Error.outOfBounds }
            guard let page = variables[$0] else { return }
            output.appendPage(page)
        }
        return output
    }
}
