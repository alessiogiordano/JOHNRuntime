//
//  Execution+Redirection.swift
//  
//
//  Created by Alessio Giordano on 13/04/23.
//

import Foundation
import AsyncHTTPClient
import NIOCore

extension Execution {
    // MARK: Forked from AsyncHTTPClient.HTTPClient+execute.executeAndFollowRedirectsIfNeeded(...)
    /// This method replaces the execute(_ request: timeout:) method from the Async HTTP Client library to have the redirection follow the expressed configuration in the JOHN stage rather than a global setting for the HTTPClient
    func sendRequest(_ request: HTTPClientRequest, timeout: TimeAmount = .seconds(30), following redirectCount: Int? = nil) async throws -> HTTPClientResponse {
        var currentRequest = request
        /// Since RedirectState is an internal type of the Async HTTP Client library, it is replaced with an integer count of the remaining redirects
        /// JOHN sets 5 as the default maximum number of redirects, before throwing an error
        let redirectCount = redirectCount ?? 5
        var remainingRedirects = redirectCount
        
        // MARK: Additional cookie logic
        /// The original request is the one made by the stage, therefore if a cookie header is already present, the user is explicitly trying to override the stored cookies, in which case the behavior will be reverted as if there was no cookie capability in JOHN whatsoever
        /// No cookies will be set or
        let originalRequestOverridesCookieBehaviour = request.headers.contains(name: "Cookie")
        self.setInheritedCookies(on: &currentRequest, overridingExistingHeader: false)

        // this loop is there to follow potential redirects
        while true {
            /// Check for task cancellation
            try Task.checkCancellation()
            /// The original code uses the internal types HTTPClientRequest.Prepared() and HTTPClient.executeCancellable
            /// I replace those with the public execute(_ request: timeout:) since the http client is known to not follow redirections
            if remainingRedirects == redirectCount {
                // MARK: willStartHTTPRequest Event
                self.delegate?.debug(willStartHTTPRequest: currentRequest)
            } else {
                // MARK: willStartHTTPRedirect Event
                self.delegate?.debug(willStartHTTPRedirect: currentRequest, count: redirectCount - remainingRedirects)
            }
            ///
            let response = try await self.httpClient.execute(currentRequest, timeout: timeout)
            ///
            if remainingRedirects == redirectCount {
                // MARK: didEndHTTPRequest Event
                self.delegate?.debug(didEndHTTPRequest: currentRequest, response: response)
            } else {
                // MARK: didEndHTTPRedirect Event
                self.delegate?.debug(didEndHTTPRedirect: currentRequest, count: redirectCount - remainingRedirects, response: response)
            }
            
            // MARK: Additional cookie logic
            if originalRequestOverridesCookieBehaviour == false, let url = URL(string: currentRequest.url) {
                self.applyCookieChanges(from: response, of: url)
            }

            /// Replacing RedirectState with Int
            /// A value of 0 redirect counts is equivalent to configuring the HTTPClient with redirect following disabled
            guard redirectCount > 0 else {
                // a `nil` redirectState means we should not follow redirects
                return response
            }
            
            /// From AsyncHTTPClient.RedirectState, extractRedirectTarget(status:_, originalURL:_, originalScheme:_)
            switch response.status {
            case .movedPermanently, .found, .seeOther, .notModified, .useProxy, .temporaryRedirect, .permanentRedirect:
                break
            default:
                /// Returning response instead of nil redirectURL
                return response
            }
            
            guard let location = response.headers.first(name: "Location") else {
                /// Returning response instead of nil redirectURL
                return response
            }
            
            /// HTTPClientRequest.Prepared() is not public, so the external string representation of the original request url must be converted to Foundation.URL to generste the redirect url
            guard let originalURL = URL(string: currentRequest.url),
                  let redirectURL = URL(string: location, relativeTo: originalURL) else {
                /// Returning response instead of nil redirectURL
                return response
            }
            /// From AsyncHTTPClient.DeconstructedURL
            guard let originalScheme = originalURL.scheme?.lowercased(),
                  let redirectScheme = redirectURL.scheme?.lowercased() else {
                throw HTTPClientError.emptyScheme
            }
            /// From AsyncHTTPClient.Scheme.supportsRedirects()
            switch originalScheme {
            case "http", "https":
                switch redirectScheme {
                case "http", "https":
                    /// Breaking from switch to execute the redirection instead of returning true
                    break
                case "unix", "http+unix", "https+unix":
                    /// Returning response instead of nil redirectURL
                    return response
                default:
                    throw HTTPClientError.unsupportedScheme(redirectScheme)
                }
            case "unix", "http+unix", "https+unix":
                /// Breaking from switch to execute the redirection instead of returning true
                break
            default:
                throw HTTPClientError.unsupportedScheme(originalScheme)
            }
            if redirectURL.isFileURL {
                /// Returning response instead of nil redirectURL
                return response
            }
            
            // validate that we do not exceed any limits or are running circles
            /// Replacing RedirectState with Int
            guard remainingRedirects > 0 else {
                throw HTTPClientError.redirectLimitReached
            }
            remainingRedirects -= 1
            
            /// From AsyncHTTPClient.RedirectState, transformRequestForRedirect(...)
            let convertToGet: Bool
            if response.status == .seeOther, currentRequest.method != .HEAD {
                convertToGet = true
            } else if response.status == .movedPermanently || response.status == .found, currentRequest.method == .POST {
                convertToGet = true
            } else {
                convertToGet = false
            }
            var method = currentRequest.method
            var headers = currentRequest.headers
            var body = currentRequest.body
            if convertToGet {
                method = .GET
                body = nil
                headers.remove(name: "Content-Length")
                headers.remove(name: "Content-Type")
            }
            
            /// From AsyncHTTPClient.HTTPHandler, URL.hasTheSameOrigin(as:_)
            if !(originalURL.host == redirectURL.host && originalURL.scheme == redirectURL.scheme && originalURL.port == redirectURL.port) {
                headers.remove(name: "Origin")
                headers.remove(name: "Cookie")
                headers.remove(name: "Authorization")
                headers.remove(name: "Proxy-Authorization")
            }
            
            /// From AsyncHTTPClient.HTTPClientRequest+Prepared, followingRedirect(from:_, to:_, status:_)
            var newRequest = HTTPClientRequest(url: redirectURL.absoluteString)
            newRequest.method = method
            newRequest.headers = headers
            newRequest.body = body
            
            /// HTTPClientRequest.Body.Mode is an internal type, so it is not possible to check whatever it can be consumed multiple times and prevent the redirection by returning the last response
            
            currentRequest = newRequest
            
            // MARK: Additional cookie logic
            /// Cookies are set on the next request of the redirect chain, reflecting values that may have been set by the current request
            /// The default behavior is to keep the cookies set on the previous request, as long as the origin is the same, with no consideration given for paths or subdomain changes
            if originalRequestOverridesCookieBehaviour == false {
                self.setInheritedCookies(on: &currentRequest, overridingExistingHeader: true)
            }
        }
    }
}
