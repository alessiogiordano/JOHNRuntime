//
//  URL+appendingQueryItems.swift
//  
//
//  Created by Alessio Giordano on 11/01/23.
//

import Foundation

extension URL {
    /// Returns a URL constructed by appending the given list of `URLQueryItem` to self.
    /// - Parameter queryItems: A list of `URLQueryItem` to append to the receiver.
    @available(macOS 10.10, iOS 8.0, *)
    public func appending(queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        var items = components?.queryItems ?? []
        items.append(contentsOf: queryItems)
        components?.queryItems = items
        return components?.url ?? self
    }
}
