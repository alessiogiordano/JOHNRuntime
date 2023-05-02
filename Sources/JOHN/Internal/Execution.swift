//
//  Execution.swift
//  
//
//  Created by Alessio Giordano on 23/12/22.
//

import Foundation
import AsyncHTTPClient

class Execution {
    enum Error: Swift.Error { case statusNotValid, unableToEncodeObjectAsForm }
    ///
    let httpClient: HTTPClient
    ///
    var outputs: [IOProtocol?]
    var temporaryPaginationOutput: IOProtocol?
    var variables: [IOProtocol?] {
        if let temporaryPaginationOutput {
            return [outputs, [temporaryPaginationOutput]].flatMap { $0 }
        } else {
            return outputs
        }
    }
    ///
    var credentials: JOHN.Options.Credentials?
    
    /// Domain -> Path -> Name
    var cookies: [String: [String: [String: HTTPClient.Cookie]]] = [:]
    ///
    var identifiedResponses: [String: [HTTPClientResponse]] = [:]
    var currentPaginationCount: Int = 0
    var uniqueDeferedIdentifiers: Set<String> = .init()
    var deferedRequests: [(request: HTTPClientRequest, redirects: Int?, status: [Int]?)] = []
    /// unowned(unsafe) /// weak
    weak var delegate: (any DebugDelegate)?
    var currentStageIndex: Int {
        outputs.count
    }
    ///
    init(with options: JOHN.Options, parameters: Parameters? = nil) throws {
        self.outputs = []
        self.credentials = options.credentials
        self.delegate = options.delegate
        switch options.provider {
        case .createNew:
            self.httpClient = .init(eventLoopGroupProvider: .createNew, configuration: .init(redirectConfiguration: .disallow))
        case .sharedEventLoop(let eventLoop):
            self.httpClient = .init(eventLoopGroupProvider: .shared(eventLoop), configuration: .init(redirectConfiguration: .disallow))
        }
        self.outputs.append(try verifyInput(options.input, with: parameters))
    }
    func update(with options: JOHN.Options, parameters: Parameters? = nil) throws {
        self.outputs = []
        self.credentials = options.credentials
        self.delegate = options.delegate
        self.temporaryPaginationOutput = nil
        self.currentPaginationCount = 0
        self.outputs.append(try verifyInput(options.input, with: parameters))
    }
    func executeDeferedRequests() async throws {
        var deferedRequestIndex = 0
        for (request, redirect, status) in deferedRequests {
            // MARK: willExecuteDeferedRequest Event
            deferedRequestIndex += 1
            self.delegate?.debug(willExecuteDeferedRequest: request, index: deferedRequestIndex)
            let response = try await self.sendRequest(request, following: redirect)
            if let status, status.contains(Int(response.status.code)) == false {
                throw Execution.Error.statusNotValid
            }
        }
        deferedRequests.removeAll()
    }
    deinit {
        self.httpClient.shutdown({ _ in })
    }
}

extension Stage {
    func execute(in context: Execution) async throws -> IOProtocol? {
        /// Verify assertions
        try verifyAssertion(in: context)
        /// Apply requested cookie changes
        applyCookieChanges(on: context)
        /// Defered and identified requests that have already been encountered in some form do not get executed again
        let willDeferStage: () -> () = {
            // MARK: willDeferStage Event
            context.delegate?.debug(willDeferStage: context.currentStageIndex)
        }
        if self.defer == true, let id {
            if context.uniqueDeferedIdentifiers.contains(id) {
                willDeferStage()
                return nil
            } else if context.identifiedResponses[id] != nil {
                context.uniqueDeferedIdentifiers.insert(id)
                willDeferStage()
                return nil
            }
        }
        /// Check if the request has been marked with an identifier, if so use the stored value instead of making another request
        if let id,
           let responses = context.identifiedResponses[id],
           responses.count > context.currentPaginationCount {
            // MARK: didRetreiveCachedHTTPResponse Event
            context.delegate?.debug(didRetreiveCachedHTTPResponse: responses[context.currentPaginationCount], withId: id)
            return try await processResponse(responses[context.currentPaginationCount], with: context)
        } else {
            /// The url encoding is necessary to safely interpolate the url into an existing url, but if the variable contains a full url, it will lead to non-encodable parts being mistakenly encoded
            let url = try Variable.substitute(outputs: context.variables, in: self.url, urlEncoded: self.url.first != "$")
            var request = HTTPClientRequest(url: url)
            /// Query
            if let query, let url = URL(string: url) {
                request.url = url
                    .appending(queryItems: try query.map { URLQueryItem(name: $0.key, value: try Variable.substitute(outputs: context.variables, in: $0.value)) })
                    .absoluteString
            }
            /// Method
            if let method { request.method = .init(rawValue: (try Variable.substitute(outputs: context.variables, in: method)).uppercased()) }
            /// Headers
            if let headers { request.headers = .init(try headers.map { ($0.key, try Variable.substitute(outputs: context.variables, in: $0.value)) }) }
            /// Authorization Header
            try setAuthorizationHeader(from: context, on: &request)
            /// Request body
            switch body {
            case .text(let body):
                request.body = .bytes(.init(string: try Variable.substitute(outputs: context.variables, in: body)))
            case .dictionary(let body):
                let substitutedBody = try body.reduce(into: [String: Body.DictionaryValue]()) { body, element in
                    if case .string(let value) = element.value {
                        body[try Variable.substitute(outputs: context.variables, in: element.key)] = .string(try Variable.substitute(outputs: context.variables, in: value))
                    } else {
                        body[try Variable.substitute(outputs: context.variables, in: element.key)] = element.value
                    }
                }
                switch self.encode {
                case .form:
                    let encodedBody = substitutedBody.reduce(into: "") { output, element in
                        guard let key = element.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                              let value = element.value.description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        else { return }
                        output += "\(output.count != 0 ? "&" : "")\(key)=\(value)"
                    }
                    request.body = .bytes(.init(string: encodedBody))
                    if !request.headers.contains(name: "Content-Type") {
                        request.headers.replaceOrAdd(name: "Content-Type", value: "application/x-www-form-urlencoded")
                    }
                default:
                    request.body = .bytes(try JSONEncoder().encode(substitutedBody))
                    if !request.headers.contains(name: "Content-Type") {
                        request.headers.add(name: "Content-Type", value: "application/json")
                    }
                }
            case .object(let body):
                if case .form = self.encode {
                    throw Execution.Error.unableToEncodeObjectAsForm
                }
                request.body = .bytes(try JSONEncoder().encode(try body.mapValues { value in
                    if case .string(let value) = value {
                        return .string(try Variable.substitute(outputs: context.variables, in: value))
                    } else {
                        return value
                    }
                } mapKeys: { key in
                    try Variable.substitute(outputs: context.variables, in: key)
                }))
                if !request.headers.contains(name: "Content-Type") {
                    request.headers.add(name: "Content-Type", value: "application/json")
                }
            case .none: break
            }
            if self.defer == true {
                /// Defered requests happen after all the others, therefore cannot block subsequent requests in the pipeline by ever returning any value
                context.deferedRequests.append((request, self.redirects, self.status))
                if let id {
                    context.uniqueDeferedIdentifiers.insert(id)
                }
                return nil
            } else {
                /// Send request
                let response = try await context.sendRequest(request, following: self.redirects)
                if let status, status.contains(Int(response.status.code)) == false {
                    throw Execution.Error.statusNotValid
                }
                /// Store request if marked with an identifier
                if let id {
                    if context.identifiedResponses[id] != nil {
                        context.identifiedResponses[id]?.append(response)
                    } else {
                        context.identifiedResponses[id] = [response]
                    }
                    // MARK: didStoreCachedHTTPResponse Event
                    context.delegate?.debug(didStoreCachedHTTPResponse: response, withId: id)
                }
                return try await processResponse(response, with: context)
            }
        }
    }
    func processResponse(_ response: HTTPClientResponse, with context: Execution? = nil) async throws -> (any IOProtocol)? {
        if self.yield == .headers {
            var headers: [String: String] = [:]
            /// Reversed so that the first instance of a header replaces all the other ones
            response.headers.reversed().forEach { header in
                headers[header.name] = header.value
            }
            return IOPayload(dictionary: headers)
        } else if self.yield == .cookies {
            var cookies: [String: String] = [:]
            if let url = URL(string: url), let domain = url.rfc6265CompliantDomain {
                /// Reversed so that the first instance of a cookie replaces all the other ones
                response.headers["Set-Cookie"].reversed().forEach {
                    guard let cookie = HTTPClient.Cookie(header: $0, defaultDomain: domain) else { return }
                    cookies[cookie.name] = cookie.value
                }
            }
            return IOPayload(dictionary: cookies)
        } else {
            var decodingStrategy: Decode = self.decode ?? .auto
            if decodingStrategy == .auto {
                if let contentType = response.headers.first(name: "Content-Type") {
                    if contentType.contains("application/json") {
                        decodingStrategy = .json
                    } else if contentType.contains("application/x-www-form-urlencoded") {
                        decodingStrategy = .form
                    } else if contentType.contains("text/html") || contentType.contains("application/xhtml+xml") {
                        decodingStrategy = .html
                    } else if contentType.contains("application/soap+xml") || contentType.contains("application/soap") {
                        decodingStrategy = .soap
                    } else if contentType.contains("text/xml") || contentType.contains("application/xml") || contentType.hasSuffix("+xml") {
                        decodingStrategy = .xml
                    } else if contentType.contains("application/octet-stream") || contentType.hasPrefix("audio/") || contentType.hasPrefix("image/") || contentType.hasPrefix("video/") || contentType.hasPrefix("font/") || contentType.contains("application/pdf") || contentType.contains("application/zip") || contentType.contains("application/x-7z-compressed") || contentType.contains("application/vnd.rar") || contentType.contains("application/msword") || contentType.contains("application/vnd.openxmlformats-officedocument.wordprocessingml.document") || contentType.contains("application/vnd.ms-powerpoint") || contentType.contains("application/vnd.openxmlformats-officedocument.presentationml.presentation") || contentType.contains("application/vnd.ms-excel") || contentType.contains("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") {
                        /// Popular binary MIME types as listed by the Mozilla Developer Network
                        /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
                        decodingStrategy = .base64
                    } else {
                        decodingStrategy = .raw
                    }
                } else {
                    decodingStrategy = .raw
                }
            }
            
            // MARK: willStartBufferingBody Event
            context?.delegate?.debug(willStartBufferingBody: Int(response.headers["Content-Length"].first ?? "0") ?? 0)
            var body = ""
            var data: Data = .init()
            for try await buffer in response.body {
                /// Check for task cancellation
                try Task.checkCancellation()
                if decodingStrategy == .base64 {
                    data.append(.init(buffer: buffer))
                } else {
                    body.append(contentsOf: String(buffer: buffer))
                }
            }
            if decodingStrategy == .base64 {
                body = data.base64EncodedString()
            }
            // MARK: didEndBufferingBody Event
            context?.delegate?.debug(didEndBufferingBody: body.count, value: body)
            
            // MARK: willProcessBodyAs Event
            context?.delegate?.debug(willProcessBodyAs: decodingStrategy.rawValue)
            switch decodingStrategy {
                case .json:
                    return IOPayload(json: body)
                case .form:
                    return IOPayload(webForm: body)
                case .xml:
                    /// public func getString(at index: Int, length: Int) -> String? in Swift-NIO always uses Unicode.UTF8.self encoding
                    return await IOMarkup(xml: body.data(using: .utf8))
                case .xmlJson:
                    // MARK: XML-JSON is a less efficient version of XML decoding that parses etherogeneous hierarchies
                    return await IOMarkup(xml: body.data(using: .utf8), containingJSON: true)
                case .soap:
                    return await IOMarkup(soap: body.data(using: .utf8))
                case .soapJson:
                    return await IOMarkup(soap: body.data(using: .utf8), containingJSON: true)
                case .html:
                    return await IOMarkup(html: body.data(using: .utf8))
                default:
                    return IOPayload(text: body)
            }
        }
    }
}
