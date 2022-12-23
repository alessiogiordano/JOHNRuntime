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
        case stage, `subscript`
    }
    enum ParsingError: Error {
        case NaN, garbageCharacters, unterminatedSubscript
    }
    init(string: String) throws {
        let input = string.first != "$" ? string : String(string.dropFirst())
        
        var temp = ""
        
        var stage: Int?
        var path: [Path] = []
        
        var parsingPhase: ParsingPhase? = .stage
        for character in input {
            if parsingPhase == nil {
                if character == "[" {
                    parsingPhase = .subscript
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
                    if character == "[" {
                        parsingPhase = .subscript
                    } else {
                        throw ParsingError.garbageCharacters
                    }
                }
            } else if parsingPhase == .subscript {
                if character == "]" {
                    if let parsedChild = Int(temp) {
                        /// Child
                        path.append(.child(parsedChild))
                    } else {
                        /// Attribute
                        path.append(.attribute(temp))
                    }
                    temp = ""
                    parsingPhase = nil
                } else {
                    temp.append(character)
                }
            }
        }
        if temp.count > 0 {
            if parsingPhase == .stage {
                guard let parsedStage = Int(temp) else {
                    throw ParsingError.NaN
                }
                stage = parsedStage
            } else {
                throw ParsingError.unterminatedSubscript
            }
        }
        temp = ""
        parsingPhase = nil
        
        guard let stage else { throw ParsingError.NaN }
        self.stage = stage
        self.path = path
    }
}
