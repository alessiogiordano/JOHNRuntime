//
//  Stage+Repetition.swift
//  
//
//  Created by Alessio Giordano on 22/02/23.
//

import Foundation
import AsyncHTTPClient

struct Repetition: Codable, Equatable {
    enum Error: Swift.Error { case notRequested, notAllowed }
    ///
    let start: Int?
    let step: Int?
    let stop: Int?
    let variable: String?
}

extension Stage {
    func `repeat`(until stop: Int, bearing credentials: Options.Credentials? = nil, with variables: [(any IOProtocol)?], on client: HTTPClient? = nil) async throws -> IOPagination? {
        guard let repetition = self.repeat else { throw Repetition.Error.notRequested }
        guard stop > 0 else { throw Repetition.Error.notAllowed }
        /// Setup
        let start = repetition.start ?? 0
        let step = (repetition.step ?? 1) > 0 ? (repetition.step ?? 1) : 1
        let stop = (repetition.stop ?? stop) < stop ? (repetition.stop ?? stop) : stop
        var output = (try? self.merge(from: variables)) ?? IOPagination(wrappedPages: [], mergingPolicy: self.merge)
        output.iterator = .init(variable: repetition.variable ?? "i", chunk: step, offset: start)
        /// Iterate
        var count = 0
        repeat {
            guard let page = try? await self.execute(with: [variables, [output]].flatMap { $0 }, bearing: credentials, on: client)
                else { break }
            output.appendPage(page)
            count = output.iterator!.advance()
        } while (count < stop)
        /// Return
        output.iterator = nil
        return output
    }
}
