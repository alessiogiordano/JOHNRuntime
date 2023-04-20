//
//  DebugDelegate.swift
//  
//
//  Created by Alessio Giordano on 18/04/23.
//

import Foundation
import AsyncHTTPClient

public protocol DebugDelegate: AnyObject {
    /// Sent by the plugin to the debug delegate after it begins execution.
    func debug(didStartPlugin plugin: JOHN, withOptions options: JOHN.Options)
    /// Sent by the plugin to the debug delegate after it begins the processing of a stage.
    func debug(didStartStage stage: Int)
    
    // MARK: Deferal
    
    /// Sent by the plugin to the debug delegate before it appends a stage to the list of deferedRequests and skips its execution.
    func debug(willDeferStage stage: Int)
    /// Sent by the plugin to the debug delegate before it sends an HTTP request that have been previously defered.
    func debug(willExecuteDeferedRequest request: HTTPClientRequest, index: Int)
    
    // MARK: Repetition
    
    /// Sent by the plugin to the debug delegate before it starts processing a repetition directive of a stage.
    func debug(willStartRepetitionAt start: Int, repeatingUntil stop: Int, step: Int)
    /// Sent by the plugin to the debug delegate after it increases the value of the counter of a stage's repetition directive.
    func debug(didIncreaseCounter counter: Int, startingAt start: Int, repeatingUntil stop: Int, step: Int)
    /// Sent by the plugin to the debug delegate after it ends processing a repetition directive of a stage.
    func debug(didEndRepetitionAt counter: Int, startingAt start: Int, repeatingUntil stop: Int, step: Int)
    /// Sent by the plugin to the debug delegate before it starts processing a repetition that has been cached with an identifier of a stage.
    func debug(willStartCachedRepetitionWith id: String, repeatingUntil count: Int)
    /// Sent by the plugin to the debug delegate after it ends processing a repetition that has been cached with an identifier of a stage.
    func debug(didEndCachedRepetitionWith id: String, repeatingUntil count: Int)
    
    // MARK: Merger
    
    /// Sent by the plugin to the debug delegate before it merges the current stage with a set of stages identified by their index in the pipeline.
    func debug(didMergeStage stage: Int, withStages stages: [Int], defaultPolicy: String, overridenBy policies: [String: String])
    
    // MARK: Assertion
    
    /// Sent by the plugin to the debug delegate after an exists assertion succeded.
    func debug(didPassExistsAssertion value: String, assertion: Bool)
    /// Sent by the plugin to the debug delegate after a contained assertion succeded.
    func debug(didPassContainedAssertion value: String, assertion: [String])
    /// Sent by the plugin to the debug delegate after an exists assertion succeded.
    func debug(didFailExistsAssertion value: String, assertion: Bool)
    /// Sent by the plugin to the debug delegate after a contained assertion succeded.
    func debug(didFailContainedAssertion value: String, assertion: [String])
    
    // MARK: Cookies
    
    /// Sent by the plugin to the debug delegate after it stores a cookie on its execution context.
    func debug(didStoreCookie name: String, value: String, domain: String, path: String)
    /// Sent by the plugin to the debug delegate after it removes a cookie from its execution context.
    func debug(didDeleteCookie name: String, domain: String, path: String)
    /// Sent by the plugin to the debug delegate after it sets a cookie from its execution context on an HTTP request.
    func debug(didSetCookieOnRequest request: HTTPClientRequest, name: String, value: String)
    
    // MARK: Authorization
    
    /// Sent by the plugin to the debug delegate after it sets the authorization header with basic authentication on an HTTP request
    func debug(didAuthorizeRequest request: HTTPClientRequest, withUsername username: String, password: String)
    /// Sent by the plugin to the debug delegate after it sets the authorization header with bearer authentication on an HTTP request
    func debug(didAuthorizeRequest request: HTTPClientRequest, withBearerToken token: String)
    
    // MARK: Execution
    
    /// Sent by the plugin to the debug delegate before it sends an HTTP request.
    func debug(willStartHTTPRequest request: HTTPClientRequest)
    /// Sent by the plugin to the debug delegate before it sends an HTTP request following a redirect response status code.
    func debug(willStartHTTPRedirect request: HTTPClientRequest, count: Int)
    /// Sent by the plugin to the debug delegate after it receives an HTTP response.
    func debug(didEndHTTPRequest request: HTTPClientRequest, response: HTTPClientResponse)
    /// Sent by the plugin to the debug delegate after it receives an HTTP response following a redirect request.
    func debug(didEndHTTPRedirect request: HTTPClientRequest, count: Int, response: HTTPClientResponse)
    /// Sent by the plugin to the debug delegate after it stores an HTTP response with the provided identifier.
    func debug(didStoreCachedHTTPResponse response: HTTPClientResponse, withId id: String)
    /// Sent by the plugin to the debug delegate after it retreives a cached HTTP response with the provided identifier.
    func debug(didRetreiveCachedHTTPResponse response: HTTPClientResponse, withId id: String)
    
    // MARK: Body
    
    /// Sent by the plugin to the debug delegate before it starts collecting the response body from the response buffer.
    func debug(willStartBufferingBody length: Int)
    /// Sent by the plugin to the debug delegate after it collects all the response body in a string.
    func debug(didEndBufferingBody length: Int, value: String)
    /// Sent by the plugin to the debug delegate after it collects all the response body in a string.
    func debug(willProcessBodyAs type: String)
    
    /// Sent by the plugin to the debug delegate before it completes the processing of a stage.
    func debug(didEndStage stage: Int, output: Any?)
    /// Sent by the plugin to the debug delegate before it ends execution.
    func debug(didEndPlugin plugin: JOHN, result: AnyResult)
}

public extension DebugDelegate {
    func debug(didStartPlugin plugin: JOHN, withOptions options: JOHN.Options) {}
    func debug(didStartStage stage: Int) {}
    func debug(willDeferStage stage: Int) {}
    func debug(willExecuteDeferedRequest request: HTTPClientRequest, index: Int) {}
    func debug(willStartRepetitionAt start: Int, repeatingUntil stop: Int, step: Int) {}
    func debug(didIncreaseCounter counter: Int, startingAt start: Int, repeatingUntil stop: Int, step: Int) {}
    func debug(didEndRepetitionAt counter: Int, startingAt start: Int, repeatingUntil stop: Int, step: Int) {}
    func debug(willStartCachedRepetitionWith id: String, repeatingUntil count: Int) {}
    func debug(didEndCachedRepetitionWith id: String, repeatingUntil count: Int) {}
    func debug(didMergeStage stage: Int, withStages stages: [Int], defaultPolicy: String, overridenBy policies: [String: String]) {}
    func debug(didPassExistsAssertion value: String, assertion: Bool) {}
    func debug(didPassContainedAssertion value: String, assertion: [String]) {}
    func debug(didFailExistsAssertion value: String, assertion: Bool) {}
    func debug(didFailContainedAssertion value: String, assertion: [String]) {}
    func debug(didStoreCookie name: String, value: String, domain: String, path: String) {}
    func debug(didDeleteCookie name: String, domain: String, path: String) {}
    func debug(didSetCookieOnRequest request: HTTPClientRequest, name: String, value: String) {}
    func debug(didAuthorizeRequest request: HTTPClientRequest, withUsername username: String, password: String) {}
    func debug(didAuthorizeRequest request: HTTPClientRequest, withBearerToken token: String) {}
    func debug(willStartHTTPRequest request: HTTPClientRequest) {}
    func debug(willStartHTTPRedirect request: HTTPClientRequest, count: Int) {}
    func debug(didEndHTTPRequest request: HTTPClientRequest, response: HTTPClientResponse) {}
    func debug(didEndHTTPRedirect request: HTTPClientRequest, count: Int, response: HTTPClientResponse) {}
    func debug(didStoreCachedHTTPResponse response: HTTPClientResponse, withId id: String) {}
    func debug(didRetreiveCachedHTTPResponse response: HTTPClientResponse, withId id: String) {}
    func debug(willStartBufferingBody length: Int) {}
    func debug(didEndBufferingBody length: Int, value: String) {}
    func debug(willProcessBodyAs type: String) {}
    func debug(didEndStage stage: Int, output: Any?) {}
    func debug(didEndPlugin plugin: JOHN, result: AnyResult) {}
}
