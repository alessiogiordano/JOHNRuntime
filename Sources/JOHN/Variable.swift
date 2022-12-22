//
//  Variable.swift
//  
//
//  Created by Alessio Giordano on 22/12/22.
//

import Foundation

struct Variable {
    let stage: Int
    let path: [Path]
    enum Path {
        case attribute(String), child(Int)
    }
    enum ParsingPhase {
        case stage, attribute, child
    }
    enum ParsingError: Error {
        case NaN, garbageCharacters
    }
    init(string: String) throws {
        let input = string.first != "$" ? string : String(string.dropFirst())
        
        var temp = ""
        
        var stage: Int?
        var path: [Path] = []
        
        var parsingPhase: ParsingPhase? = .stage
        for character in input {
            if parsingPhase == nil {
                
            } else if parsingPhase == .stage {
                
            } else if parsingPhase == .child {
                
            } else if parsingPhase == .attribute {
                
            }
            if parsingPhase == nil {
                if character == "." {
                    parsingPhase = .attribute
                } else if character == "[" {
                    parsingPhase = .child
                } else {
                    throw ParsingError.garbageCharacters
                }
            } else if parsingPhase == .stage {
                if character.isNumber {
                    temp.append(character)
                } else {
                    guard let parsedStage = Int(temp) else {
                        throw ParsingError.NaN
                    }
                    stage = parsedStage
                    temp = ""
                    if character == "." {
                        parsingPhase = .attribute
                    } else if character == "[" {
                        parsingPhase = .child
                    } else {
                        throw ParsingError.garbageCharacters
                    }
                }
            } else if parsingPhase == .child {
                if character.isNumber {
                    temp.append(character)
                } else if character == "]" {
                    guard let parsedChild = Int(temp) else {
                        throw ParsingError.NaN
                    }
                    path.append(.child(parsedChild))
                    temp = ""
                    parsingPhase = nil
                } else {
                    throw ParsingError.garbageCharacters
                }
            } else if parsingPhase == .attribute {
                if character != "." && character != "[" {
                    temp.append(character)
                } else {
                    path.append(.attribute(temp))
                    temp = ""
                    if character == "[" {
                        parsingPhase = .child
                    }
                }
            }
        }
        if temp.count > 0 {
            if parsingPhase == .stage {
                guard let parsedStage = Int(temp) else {
                    throw ParsingError.NaN
                }
                stage = parsedStage
            } else if parsingPhase == .child {
                guard let parsedChild = Int(temp) else {
                    throw ParsingError.NaN
                }
                path.append(.child(parsedChild))
            } else if parsingPhase == .attribute {
                path.append(.attribute(temp))
            }
        }
        temp = ""
        parsingPhase = nil
        
        guard let stage else { throw ParsingError.NaN }
        self.stage = stage
        self.path = path
    }
}
