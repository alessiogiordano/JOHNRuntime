//
//  Cookies.swift
//  
//
//  Created by Alessio Giordano on 14/04/23.
//
//  https://www.rfc-editor.org/rfc/rfc6265#section-5.2.3

import Foundation
import AsyncHTTPClient
import CAsyncHTTPClient

enum Cookies: Codable, Equatable, ExpressibleByBooleanLiteral, ExpressibleByDictionaryLiteral {
    case inherit, delete, set([String: CookieValue])
    static let allowedCharacterSet: CharacterSet = .alphanumerics
                                                   .union(["!", "#", "$", "%", "&", "'", "*",
                                                           "+", "-", ".", "^", "_", "`", "|", "~"])
    
    enum CookieValue: Codable, Equatable, ExpressibleByStringLiteral, ExpressibleByBooleanLiteral {
        case inherit, delete, set(String)
        /// ExpressibleByStringLiteral
        typealias StringLiteralType = String
        public init(stringLiteral value: String) {
            self = .set(value)
        }
        /// ExpressibleByBooleanLiteral
        typealias BooleanLiteralType = Bool
        init(booleanLiteral value: Bool) {
            self = value ? .inherit : .delete
        }
        /// Codable
        public init(from decoder: Decoder) throws {
            do {
                self = (try decoder.singleValueContainer().decode(Bool.self)) ? .inherit : .delete
            } catch {
                self = .set(try decoder.singleValueContainer().decode(String.self))
            }
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .inherit:          try container.encode(true)
                case .delete:           try container.encode(false)
                case .set(let value):   try container.encode(value)
            }
        }
    }
    /// ExpressibleByBooleanLiteral
    typealias BooleanLiteralType = Bool
    init(booleanLiteral value: Bool) {
        self = value ? .inherit : .delete
    }
    /// ExpressibleByDictionaryLiteral
    typealias Key = String
    typealias Value = CookieValue
    public init(dictionaryLiteral elements: (String, CookieValue)...) {
        var dictionary: [String: CookieValue] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self = .set(dictionary)
    }
    /// Codable
    public init(from decoder: Decoder) throws {
        do {
            self = .set(try decoder.singleValueContainer().decode([String: CookieValue].self))
        } catch {
            self = (try decoder.singleValueContainer().decode(Bool.self)) ? .inherit : .delete
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .inherit:          try container.encode(true)
            case .delete:           try container.encode(false)
            case .set(let value):   try container.encode(value)
        }
    }
}

extension URL {
    /// RFC 6265    5.2.3.  The Domain Attribute
    var rfc6265CompliantDomain: String? {
        guard let domain = self.host?.lowercased() else { return nil }
        /// Empty domains are explicitly required to be skipped
        guard !domain.isEmpty else { return nil }
        /// Leading dots are required to be dropped
        guard domain.first != "." else { return String(domain.dropFirst()) }
        return domain
    }
    /// RFC 6265    5.2.4.  The Path Attribute
    var rfc6265CompliantPath: String {
        self.path.first != "/" ? "/" + self.path.lowercased() : self.path.lowercased()
    }
    /// RFC 6265    5.1.4.  Paths and Path-Match
    var rfc6265DefaultCookiePath: String {
        let parentPath = self.path.lowercased()
                                    .split(separator: "/", omittingEmptySubsequences: false)
                                    .dropLast()
                                    .joined(separator: "/")
        return parentPath.first != "/" ? "/" + parentPath : parentPath
    }
}

extension Execution {
    func forEachStoredCookie(matching url: URL?, with action: (String, String, HTTPClient.Cookie) -> ()) {
        if let domain = url?.rfc6265CompliantDomain, let path = url?.rfc6265CompliantPath {
            forEachStoredCookie(matching: (domain: domain, path: path), with: action)
        }
    }
    func forEachStoredCookie(matching site: (domain: String, path: String)? = nil, with action: (String, String, HTTPClient.Cookie) -> ()) {
        self.cookies.keys.filter { site?.domain.hasSuffix($0) ?? true }.forEach { domain in
            self.cookies[domain]?.keys.filter { site?.path.hasPrefix($0) ?? true }.forEach { path in
                self.cookies[domain]?[path]?.values.forEach { cookie in
                    /// RFC 6265    4.1.2.  Semantics (Non-Normative)
                    if let expiration = cookie.expires, expiration < Date() {
                        /// The cookie shall never be sent again as it has expired. Therefore it is deleted from the store
                        /// "When the user agent receives a Set-Cookie header, the user agent stores the cookie together with its attributes.  Subsequently, when the user agent makes an HTTP request, the user agent includes the applicable, non-expired cookies in the Cookie header."
                        self.deleteCookie(cookie, domain: domain, path: path)
                    } else {
                        action(domain, path, cookie)
                    }
                }
            }
        }
    }
    func storeCookie(_ cookie: HTTPClient.Cookie, domain: String, path: String) {
        /// Create path if it doesn't exist
        if self.cookies[domain] == nil {
            self.cookies[domain] = [:]
        }
        if self.cookies[domain]?[path] == nil {
            self.cookies[domain]?[path] = [:]
        }
        /// Store the cookie
        self.cookies[domain]?[path]?.updateValue(cookie, forKey: cookie.name)
        // MARK: didStoreCookie Event
        self.delegate?.debug(didStoreCookie: cookie.name, value: cookie.value, domain: domain, path: path)
    }
    func deleteCookie(_ cookie: HTTPClient.Cookie, domain: String, path: String) {
        self.cookies[domain]?[path]?[cookie.name] = nil
        // MARK: didDeleteCookie Event
        self.delegate?.debug(didDeleteCookie: cookie.name, domain: domain, path: path)
    }
}

extension Stage {
    /// The cookies property of Stage is used to apply changes to the stored cookie set.
    /// A stage can only affect the cookies that according to the standard set out in RFC 6265 should be sent in its request, by deleting all of them or only those that match the provided name.
    /// Cookies can also be sent by providing key-value pairs.
    func applyCookieChanges(on context: Execution) {
        /// The url encoding is necessary to safely interpolate the url into an existing url, but if the variable contains a full url, it will lead to non-encodable parts being mistakenly encoded
        guard let url_string = try? Variable.substitute(outputs: context.variables, in: self.url, urlEncoded: self.url.first != "$"),
              /// First we gather the values for applying or
              let url = URL(string: url_string),
              let domain = url.rfc6265CompliantDomain else { return }
        let path = url.rfc6265CompliantPath
        let defaultPath = url.rfc6265DefaultCookiePath
        switch self.cookies {
        case .delete:
            /// All cookies that would have been sent with this request shall be deleted from the execution context
            context.forEachStoredCookie(matching: (domain: domain, path: path)) { domain, path, cookie in
                context.deleteCookie(cookie, domain: domain, path: path)
            }
        case .set(let values):
            /// Store cookie values in the execution context
            values.forEach {
                if case .set(let value) = $0.value {
                    if let value = try? Variable.substitute(outputs: context.variables, in: value) {
                        /// Create the cookie
                        let cookie = HTTPClient.Cookie(
                            name: $0.key,
                            value: value,
                            path: defaultPath,
                            domain: domain
                        )
                        /// Store the cookie
                        context.storeCookie(cookie, domain: domain, path: path)
                    }
                }
            }
            /// Delete cookies that have been marked for deletion, set the others on the request
            context.forEachStoredCookie(matching: (domain: domain, path: path)) { domain, path, cookie in
                if values.first(where: { $0.key == cookie.name })?.value == .delete {
                    /// When cookie is set to false it is deleted
                    context.deleteCookie(cookie, domain: domain, path: path)
                }
            }
        default: return
        }
    }
}

extension Execution {
    /// Following the rules set out in RFC 6265, set the cookies on the provided request
    func setInheritedCookies(on request: inout HTTPClientRequest, overridingExistingHeader: Bool = true) {
        guard !overridingExistingHeader && request.headers.contains(name: "Cookie") else { return }
        
        var matchingCookies: [HTTPClient.Cookie] = []
        
        self.forEachStoredCookie(matching: URL(string: request.url)) { _, _, cookie in
            matchingCookies.append(cookie)
        }
        
        /// According to the specification, cookies should be sorted from the largest path, downwards, in case of duplicate keys
        matchingCookies.sort { lhs, rhs in
            return lhs.path.count > rhs.path.count
        }
        /// Setting cookies in request
        let cookieString = String(matchingCookies.reduce(into: "") { string, cookie in
            guard let name = cookie.name.addingPercentEncoding(withAllowedCharacters: Cookies.allowedCharacterSet),
                  let value = cookie.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            else { return }
            string.append("\(name)=\(value); ") /// Cookies are separated with a semicolon and a space
            // MARK: didSetCookieOnRequest Event
            self.delegate?.debug(didSetCookieOnRequest: request, name: cookie.name, value: cookie.value)
        }.dropLast(2)) /// "; "
        
        /// Setting cookies in request
        request.headers.replaceOrAdd(name: "Cookie", value: cookieString)
    }
    /// For each Set-Cookie header provided by the server, set, update or remove the cookie from the stored set
    func applyCookieChanges(from response: HTTPClientResponse, of url: URL) {
        guard let domain = url.rfc6265CompliantDomain else { return }
        
        /// From AsyncHTTPClient.HTTPClient+HTTPCookie, HTTPClient.Response.cookies
        /// The following utility methods are defined in AsyncHTTPClient.HTTPClient+HTTPCookie as fileprivate extensions on String.UTF8View.SubSequence and are used to parse the components of the Set-Cookie header
        let trimmingASCIISpaces: ((String.UTF8View.SubSequence) -> String.UTF8View.SubSequence) = {
            guard let start = $0.firstIndex(where: { $0 != UInt8(ascii: " ") }) else {
                return $0[$0.endIndex..<$0.endIndex]
            }
            let end = $0.lastIndex(where: { $0 != UInt8(ascii: " ") })!
            return $0[start...end]
        }
        let parseKeyValuePair: ((String.UTF8View.SubSequence) -> (key: String.UTF8View.SubSequence, value: String.UTF8View.SubSequence)?) = {
            guard let keyValueSeparator = $0.firstIndex(of: UInt8(ascii: "=")) else {
                return nil
            }
            let trimmedName = trimmingASCIISpaces($0[..<keyValueSeparator])
            let trimmedValue = trimmingASCIISpaces($0[$0.index(after: keyValueSeparator)...])
            return (trimmedName, trimmedValue)
        }
        let parseCookieComponent: ((String.UTF8View.SubSequence) -> (key: String, value: String.UTF8View.SubSequence?)?) = {
            let (trimmedName, trimmedValue) = parseKeyValuePair($0) ?? (trimmingASCIISpaces($0), nil)
            guard !trimmedName.isEmpty else {
                return nil
            }
            return (Substring(trimmedName).lowercased(), trimmedValue)
        }

        /// From AsyncHTTPClient.HTTPClient+HTTPCookie, HTTPClient.Response.cookies
        /// Changed from compactMap to forEach since it is used in a method with no return value
        response.headers["Set-Cookie"].forEach {
            if var cookie = HTTPClient.Cookie(header: $0, defaultDomain: domain) {
                /// A mistake is made by the AsyncHTTPClient library by confusing the default-path of the cookie as the root path / instead of the one computed from the request-uri
                /// By checking whatever the path from the header is considered invalid, it is possible to correct the mistake with the correct path
                /// From AyncHTTPClient.HTTPClient+HTTPCookie.init?(header: String, defaultDomain: String)
                let components = $0.utf8.split(separator: UInt8(ascii: ";"), omittingEmptySubsequences: false)[...]
                var parsedPath: String.UTF8View.SubSequence?
                for component in components {
                    switch parseCookieComponent(component) {
                    case ("path", let value)?:
                        // Unlike other values, unspecified, empty, and invalid paths reset to the default path.
                        // https://datatracker.ietf.org/doc/html/rfc6265#section-5.2.4
                        guard let value = value, value.first == UInt8(ascii: "/") else {
                            parsedPath = nil
                            continue
                        }
                        parsedPath = value
                    default:
                        continue
                    }
                }
                /// If the parsed path is nil, then the root path / used in the parsed cookie is not correct and shall be replaced with the RFC 6265 compliant default path computed from the request URI
                if parsedPath == nil {
                    cookie.path = url.rfc6265DefaultCookiePath
                }
                
                /// RFC 6265    4.1.2.  Semantics (Non-Normative)
                if let expiration = cookie.expires, expiration < Date() {
                    /// "Notice that servers can delete cookies by sending the user agent a new cookie with an Expires attribute with a value in the past."
                    self.deleteCookie(cookie, domain: cookie.domain ?? domain, path: cookie.path)
                } else {
                    /// "When the user agent receives a Set-Cookie header, the user agent stores the cookie together with its attributes.  Subsequently, when the user agent makes an HTTP request, the user agent includes the applicable, non-expired cookies in the Cookie header."
                    self.storeCookie(cookie, domain: cookie.domain ?? domain, path: cookie.path)
                }
            }
        }
    }
}
