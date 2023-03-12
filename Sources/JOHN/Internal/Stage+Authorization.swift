//
//  Stage+Authorization.swift
//  
//
//  Created by Alessio Giordano on 11/03/23.
//

import Foundation
import AsyncHTTPClient

enum Authorization: String, Codable {
    enum Error: Swift.Error { case missing, base64EncodingFailure }
    /// Valid assertions
    case basic, bearer, none
}

extension Stage {
    func setAuthorizationHeader(from credentials: Options.Credentials?, on request: inout HTTPClientRequest) throws {
        if request.headers.contains(name: "Authorization") { return }
        switch self.authorization {
        case .basic:
            switch credentials {
            case .basic(let username, let password):
                guard let base64EncodedCredentials = "\(username):\(password)"
                    .data(using: .utf8)?.base64EncodedString()
                    else { throw Authorization.Error.base64EncodingFailure }
                request.headers.add(name: "Authorization", value: "Basic \(base64EncodedCredentials)")
            default: throw Authorization.Error.missing
            }
        case .bearer:
            switch credentials {
            case .bearer(let token):
                request.headers.add(name: "Authorization", value: "Bearer \(token)")
            default: throw Authorization.Error.missing
            }
        default: return
        }
    }
}
