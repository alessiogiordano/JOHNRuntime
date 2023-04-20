//
//  Repetition.swift
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
    func `repeat`(until stop: Int, in context: Execution) async throws -> IOPagination? {
        guard let repetition = self.repeat else { throw Repetition.Error.notRequested }
        guard self.defer != true else { throw Repetition.Error.notAllowed }
        /// Check if the request has been marked with an identifier, if so use the stored values instead of making another set of requests
        if let id, let responses = context.identifiedResponses[id], !responses.isEmpty {
            // MARK: willStartCachedRepetitionWith Event
            context.delegate?.debug(willStartCachedRepetitionWith: id, repeatingUntil: responses.count)
            var output = (try? self.merge(from: context.outputs, with: context)) ?? IOPagination(wrappedPages: [], mergingPolicy: self.merge)
            for response in responses {
                // MARK: didRetreiveCachedHTTPResponse Event
                context.delegate?.debug(didRetreiveCachedHTTPResponse: response, withId: id)
                if let page = try await processResponse(response, with: context) {
                    output.appendPage(page)
                }
            }
            // MARK: didEndCachedRepetitionWith Event
            context.delegate?.debug(didEndCachedRepetitionWith: id, repeatingUntil: responses.count)
            return output
        } else {
            guard stop > 0 else { throw Repetition.Error.notAllowed }
            /// Setup
            let start = repetition.start ?? 0
            let step = (repetition.step ?? 1) > 0 ? (repetition.step ?? 1) : 1
            let stop = (repetition.stop ?? stop) < stop ? (repetition.stop ?? stop) : stop
            // MARK: willStartRepetitionAt Event
            context.delegate?.debug(willStartRepetitionAt: start, repeatingUntil: stop, step: step)
            var output = (try? self.merge(from: context.outputs)) ?? IOPagination(wrappedPages: [], mergingPolicy: self.merge)
            output.iterator = .init(variable: repetition.variable ?? "i", chunk: step, offset: start)
            /// Iterate
            var count = 0
            repeat {
                context.temporaryPaginationOutput = output
                guard let page = try? await self.execute(in: context)
                    else { break }
                context.temporaryPaginationOutput = nil
                context.currentPaginationCount += 1
                output.appendPage(page)
                count = output.iterator!.advance()
                if count < stop {
                    // MARK: didIncreaseCounter Event
                    context.delegate?.debug(didIncreaseCounter: count, startingAt: start, repeatingUntil: stop, step: step)
                } else {
                    // MARK: didEndRepetitionAt Event
                    context.delegate?.debug(didEndRepetitionAt: count, startingAt: start, repeatingUntil: stop, step: step)
                }
            } while (count < stop)
            /// Return
            output.iterator = nil
            return output
        }
    }
}
