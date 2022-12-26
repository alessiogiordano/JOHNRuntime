//
//  Variable+Substitution.swift
//  
//
//  Created by Alessio Giordano on 22/12/22.
//

import Foundation

extension Variable {
    private enum SplittingError: Error { case unterminatedSubscript }
    private typealias StringComponent = (isVariable: Bool, value: String)
    private static func splitString(_ string: String) throws -> [StringComponent] {
        var result: [StringComponent] = []
        var temp = ""
        var parsingVariableName = false
        var parsingVariableChild = false
        for character in string {
            if parsingVariableName {
                if character.isNumber {
                    temp.append(String(character))
                } else if character == "[" {
                    parsingVariableChild = true
                    parsingVariableName = false
                    temp.append(String(character))
                } else {
                    parsingVariableName = false
                    result.append((true, temp))
                    temp = String(character)
                }
            } else if parsingVariableChild {
                temp.append(String(character))
                if character == "]" {
                    result.append((true, temp))
                    parsingVariableChild = false
                    temp = ""
                }
            } else {
                if character != "$" {
                    temp.append(String(character))
                } else {
                    if temp.last == "\\" {
                        temp = String(temp.dropLast())
                        temp.append(character)
                    } else {
                        parsingVariableName = true
                        result.append((false, temp))
                        temp = String(character)
                    }
                }
            }
        }
        if temp.count > 0 {
            if (parsingVariableChild) { throw SplittingError.unterminatedSubscript }
            result.append((parsingVariableName, temp))
            temp = ""
        }
        return result
    }
    
    enum SubstitutionError: Error {
        case overflow, notFound, corruptedPagination
    }
    
    private func traversePath(_ path: [Path], of output: Output) throws -> Output {
        var output = output
        for component in self.path {
            switch component {
            case .attribute(let name):  guard let value = output[name] else {
                                            throw SubstitutionError.notFound
                                        }
                                        output = value
                                        break
            case .child(let index):     guard let value = output[index] else {
                                            throw SubstitutionError.notFound
                                        }
                                        output = value
                                        break
            }
        }
        return output
    }
    
    public func resolve(with outputs: [Output?], expectsPagination: Bool = true) throws -> Output {
        if self.stage >= outputs.count {
            throw SubstitutionError.overflow
        }
        guard let rootOutput = outputs[self.stage] else {
            throw SubstitutionError.notFound
        }
        
        if rootOutput.source == .pagination && expectsPagination {
            guard let pages = rootOutput.wrappedValue as? [Any] else { throw SubstitutionError.corruptedPagination }
            return Output.merge(.pagination, items: try pages.map {
                var array: [Output?] = .init(repeating: nil, count: self.stage)
                array.append(Output(wrappedValue: $0))
                return try self.resolve(with: array)
            })
        } else {
            return try self.traversePath(path, of: rootOutput)
        }
    }
    
    private static func substitute(outputs: [Output?], in components: [StringComponent], urlEncoded: Bool) throws -> String {
        var result = ""
        for element in components {
            if element.isVariable {
                let parsedVariable = try Variable(string: element.value)
                let output = try parsedVariable.resolve(with: outputs, expectsPagination: false)
                guard let textContent = output.text else {
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
    
    static func substitute(outputs: [Output?], in string: String, urlEncoded: Bool = false) throws -> String {
        try Self.substitute(outputs: outputs, in: Self.splitString(string), urlEncoded: urlEncoded)
    }
}
