//
//  Variable+Substitution.swift
//  
//
//  Created by Alessio Giordano on 22/12/22.
//

import Foundation

extension Variable {
    private typealias StringComponent = (isVariable: Bool, value: String)
    private static func splitString(_ string: String) -> [StringComponent] {
        var result: [StringComponent] = []
        var temp = ""
        var parsingVariable = false
        for character in string {
            if parsingVariable {
                if character.isWhitespace {
                    parsingVariable = false
                    result.append((true, temp))
                    temp = String(character)
                } else {
                    temp.append(String(character))
                }
            } else {
                if character != "$" {
                    temp.append(String(character))
                } else {
                    if temp.last == "\\" {
                        temp = String(temp.dropLast())
                        temp.append(character)
                    } else {
                        parsingVariable = true
                        result.append((false, temp))
                        temp = String(character)
                    }
                }
            }
        }
        if temp.count > 0 {
            result.append((parsingVariable, temp))
            temp = ""
        }
        return result
    }
    
    enum SubstitutionError: Error {
        case overflow, notFound
    }
    
    private static func substitute(responses: [Response?], in components: [StringComponent], urlEncoded: Bool) throws -> String {
        var result = ""
        for element in components {
            if element.isVariable {
                let parsedVariable = try Variable(string: element.value)
                if parsedVariable.stage >= responses.count {
                    throw SubstitutionError.overflow
                }
                guard let rootResponse = responses[parsedVariable.stage] else {
                    throw SubstitutionError.notFound
                }
                var response = rootResponse
                for component in parsedVariable.path {
                    switch component {
                    case .attribute(let name):  guard let value = response[name] else {
                                                    throw SubstitutionError.notFound
                                                }
                                                response = value
                                                break
                    case .child(let index):     guard let value = response[index] else {
                                                    throw SubstitutionError.notFound
                                                }
                                                response = value
                                                break
                    }
                }
                guard let textContent = response.text else {
                    throw SubstitutionError.notFound
                }
                if urlEncoded {
                    result.append(textContent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? textContent)
                } else {
                    result.append(textContent)
                }
                
            } else {
                result.append(element.value)
            }
        }
        return result
    }
    
    static func substitute(responses: [Response?], in string: String, urlEncoded: Bool = false) throws -> String {
        try Self.substitute(responses: responses, in: Self.splitString(string), urlEncoded: urlEncoded)
    }
}
