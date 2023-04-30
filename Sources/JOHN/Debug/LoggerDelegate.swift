//
//  LoggerDelegate.swift
//  
//
//  Created by Alessio Giordano on 19/04/23.
//

import Foundation
import Logging
import AsyncHTTPClient

// MARK: The following convenience compiles correctly, it is exposed by the code completition, but complains on usage that contextual type lookup requires additional Self constraints in the extension definition
// MARK: And in any case, the weak self reference makes the delegate be instantaneously deallocated when initialized as part of the arguments
/*
public extension DebugDelegate {
    static func log(_ logger: Logger,
                    level: Logger.Level? = nil,
                    verbose: Bool = false,
                    unsafe: Bool = false) -> LoggerDelegate {
        return .init(logger: logger, level: level, verbose: verbose, unsafe: unsafe)
    }
    static func log(_ prefix: String? = nil,
                    verbose: Bool = false,
                    unsafe: Bool = false) -> LoggerDelegate {
        return .init(standardOutputWithPrefix: prefix, verbose: verbose, unsafe: unsafe)
    }
}
 */

public class LoggerDelegate {
    let verbose: Bool
    let unsafe: Bool /// Display sensitive information in the debug log, like password and tokens
    ///
    internal let logger: Logger?
    internal let level: Logger.Level?
    ///
    internal let prefix: String?
    ///
    public init(standardOutputWithPrefix prefix: String? = nil, verbose: Bool = false, unsafe: Bool = false) {
        self.prefix = prefix
        self.verbose = verbose
        self.unsafe = unsafe
        ///
        self.logger = nil
        self.level = nil
    }
    public init(logger: Logger,
         level: Logger.Level? = nil,
         verbose: Bool = false,
         unsafe: Bool = false) {
        self.logger = logger
        self.level = level
        self.verbose = verbose
        self.unsafe = unsafe
        ///
        self.prefix = nil
    }
    ///
    internal func requestString(_ request: HTTPClientRequest, verbose: Bool = false) -> String {
        if verbose {
            return """
            \(request.method.rawValue)\t\(request.url)
            HEADERS: \(request.headers.description)
            BODY: \(request.body.debugDescription)
            """
        } else {
            return "\(request.method.rawValue)\t\(request.url)"
        }
    }
    internal func print(_ shortString: String, _ longString: String? = nil) {
        let string: String
        if verbose, let longString {
            string = longString
        } else {
            string = shortString
        }
        if let logger {
            let message: Logger.Message = .init(stringLiteral: string)
            switch level {
            case .trace:
                logger.trace(message)
            case .debug:
                logger.debug(message)
            case .info:
                logger.info(message)
            case .notice:
                logger.notice(message)
            case .warning:
                logger.notice(message)
            case .error:
                logger.error(message)
            case .critical:
                logger.critical(message)
            default:
                logger.debug(message)
            }
        } else {
            if let prefix {
                Swift.print("\(prefix)\(string)")
            } else {
                Swift.print(string)
            }
        }
    }
}

extension LoggerDelegate: DebugDelegate {
    public func debug(didStartPlugin plugin: JOHN, withOptions options: JOHN.Options) {
        self.print("didStartPlugin \"\(plugin.about.name)\"", """
        didStartPlugin "\(plugin.about.name)"
        INPUT: \(options.input.debugDescription)
        CREDENTIALS: \(options.credentials.debugDescription)
        REPETITIONS: \(options.repetitions.debugDescription)
        EVENT LOOP PROVIDER: \(options.provider)
        """)
    }
    public func debug(didStartStage stage: Int) {
        self.print("didStartStage \(stage)")
    }
    public func debug(willDeferStage stage: Int) {
        self.print("willDeferStage \(stage)")
    }
    public func debug(willExecuteDeferedRequest request: HTTPClientRequest, index: Int) {
        self.print("willExecuteDeferedRequest \(index)\t\(requestString(request))", """
        willExecuteDeferedRequest \(index)
        REQUEST: \(requestString(request, verbose: true))
        """)
    }
    public func debug(willStartRepetitionAt start: Int, repeatingUntil stop: Int, step: Int) {
        self.print("willStartRepetitionAt \(start) until \(stop) by \(step)")
    }
    public func debug(didIncreaseCounter counter: Int, startingAt start: Int, repeatingUntil stop: Int, step: Int) {
        self.print("didIncreaseCounter \(counter - step) by \(step) to \(counter)")
    }
    public func debug(didEndRepetitionAt counter: Int, startingAt start: Int, repeatingUntil stop: Int, step: Int) {
        self.print("didEndRepetitionAt \(counter) startingAt \(start) cappedAt \(step)")
    }
    public func debug(willStartCachedRepetitionWith id: String, repeatingUntil count: Int) {
        self.print("willStartCachedRepetitionWithId \"\(id)\" repeatingUntil \(count)")
    }
    public func debug(didEndCachedRepetitionWith id: String, repeatingUntil count: Int) {
        self.print("didEndCachedRepetitionWithId \"\(id)\" repeatingUntil \(count)")
    }
    public func debug(didMergeStage stage: Int, withStages stages: [Int], defaultPolicy: String, overridenBy policies: [String: String]) {
        self.print("didMergeStage \(stage) with \(stages.description)", """
        didMergeStage \(stage) with \(stages.description)
        DEFAULT POLICY: \(defaultPolicy)
        POLICY OVERRIDES: \(policies.description)
        """)
    }
    public func debug(didPassExistsAssertion value: String, assertion: Bool) {
        self.print("didPassExistsAssertion \"\(value)\" \(assertion ? "EXISTS" : "DOES NOT EXIST")")
    }
    public func debug(didPassContainedAssertion value: String, assertion: [String]) {
        self.print("didPassContainedAssertion \"\(value)\"", """
        didPassContainedAssertion "\(value)"
        CONTAINED: \(assertion.description)
        """)
    }
    public func debug(didFailExistsAssertion value: String, assertion: Bool) {
        self.print("didFailExistsAssertion \"\(value)\" \(assertion ? "EXISTS" : "DOES NOT EXIST")")
    }
    public func debug(didFailContainedAssertion value: String, assertion: [String]) {
        self.print("didFailContainedAssertion \"\(value)\"", """
        didFailContainedAssertion "\(value)"
        CONTAINED: \(assertion.description)
        """)
    }
    public func debug(didStoreCookie name: String, value: String, domain: String, path: String) {
        self.print("didStoreCookie \"\(name)\"\t\"\(domain)\"", """
        didStoreCookie "\(name)"
        VALUE: \(value)
        DOMAIN: \(domain)
        PATH: \(path)
        """)
    }
    public func debug(didDeleteCookie name: String, domain: String, path: String) {
        self.print("didDeleteCookie \"\(name)\"\t\"\(domain)\"", """
        didDeleteCookie "\(name)"
        DOMAIN: \(domain)
        PATH: \(path)
        """)
    }
    public func debug(didSetCookieOnRequest request: HTTPClientRequest, name: String, value: String) {
        self.print("didSetCookieOnRequest \"\(name)\"\t\"\(request.url)\"", """
        didSetCookieOnRequest "\(name)"
        VALUE: \(value)
        REQUEST: \(requestString(request))
        """)
    }
    public func debug(didAuthorizeRequest request: HTTPClientRequest, withUsername username: String, password: String) {
        self.print("didAuthorizeRequestWithUsername \"\(username)\" \(requestString(request))", """
        didAuthorizeRequestWithUsername "\(username)"
        PASSWORD: \(self.unsafe ? password : password.indices.map { _ in "*" }.joined())
        REQUEST: \(requestString(request))
        """)
    }
    public func debug(didAuthorizeRequest request: HTTPClientRequest, withBearerToken token: String) {
        self.print("didAuthorizeRequestWithBearerToken \(requestString(request))", """
        didAuthorizeRequestWithBearerToken
        TOKEN: \(self.unsafe ? token : token.indices.map { _ in "*" }.joined())
        REQUEST: \(requestString(request))
        """)
    }
    public func debug(willStartHTTPRequest request: HTTPClientRequest) {
        self.print("willStartHTTPRequest \(requestString(request))", """
        willStartHTTPRequest \(requestString(request, verbose: true))
        """)
    }
    public func debug(willStartHTTPRedirect request: HTTPClientRequest, count: Int) {
        self.print("willStartHTTPRedirect \(count) \(requestString(request))", """
        willStartHTTPRedirect \(count) \(requestString(request, verbose: true))
        """)
    }
    public func debug(didEndHTTPRequest request: HTTPClientRequest, response: HTTPClientResponse) {
        self.print("didEndHTTPRequest \(response.status.code)\t\(request.url))\t\(response.headers["Content-Type"].first ?? "")", """
        didEndHTTPRequest \(requestString(request))
        HTTP: \(response.version.description)
        STATUS: \(response.status.code)
        CONTENT-TYPE: \(response.headers["Content-Type"].first ?? "")
        """)
    }
    public func debug(didEndHTTPRedirect request: HTTPClientRequest, count: Int, response: HTTPClientResponse) {
        self.print("didEndHTTPRedirect \(count) \(response.status.code)\t\(request.url))\t\(response.headers["Content-Type"].first ?? "")", """
        didEndHTTPRedirect \(count) \(requestString(request))
        HTTP: \(response.version.description)
        STATUS: \(response.status.code)
        CONTENT-TYPE: \(response.headers["Content-Type"].first ?? "")
        """)
    }
    public func debug(didStoreCachedHTTPResponse response: HTTPClientResponse, withId id: String) {
        self.print("didStoreCachedHTTPResponseWithId \(id)\t\(response.status.code))\t\(response.headers["Content-Type"].first ?? "")")
    }
    public func debug(didRetreiveCachedHTTPResponse response: HTTPClientResponse, withId id: String) {
        self.print("didRetreiveCachedHTTPResponse \(id)\t\(response.status.code))\t\(response.headers["Content-Type"].first ?? "")")
    }
    public func debug(willStartBufferingBody length: Int) {
        self.print("willStartBufferingBody \(length)")
    }
    public func debug(didEndBufferingBody length: Int, value: String) {
        self.print("didEndBufferingBody \(length)", """
        didEndBufferingBody \(length)
        VALUE: \(value)
        """)
    }
    public func debug(willProcessBodyAs type: String) {
        self.print("willProcessBodyAs \(type)")
    }
    public func debug(didEndStage stage: Int, output: Any?) {
        self.print("didEndStage \(stage)", """
        didEndStage \(stage)
        OUTPUT: \(output.debugDescription)
        """)
    }
    public func debug(didEndPlugin plugin: JOHN, result: AnyResult) {
        self.print("didEndPlugin \"\(plugin.about.name)\"", """
        didEndPlugin \(plugin.about.name)
        RESULT: \(result.path.map.debugDescription)
        """)
    }
}
