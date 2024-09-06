//
//  TokenType.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/28/24.
//

enum TokenType: String {
    /// Single character
    case plus, equals, semicolon, bang, slash,
         leftParen, rightParen, leftBrace, rightBrace,
         dot, comma, less, greater, leftSquare, rightSquare,
         star, minus, amper, pipe, questionMark, horDots, at,
         percent, underline, carrot
    /// Double character
    case equalsEquals, bangEquals, lessEqual, greaterEqual,
         and, or, plusEquals, plusPlus, arrayStart
    /// Literals
    case number, string, identifier, classIdentifier
    /// Keywords
    case int, If, Else, Return, bool, While, For, print, void, interface,
         property, end, implementation, yes, no, null, selfy, supery, weak,
         id, typeDef
    /// Preprocessor
    case include, define, undef, ifdef, elsePre, endif, elseifPre,
         pragma, error, warning, importPre
    /// Other
    case EOF
    
    static let variableTypes: [TokenType] = [.int, .bool, .void, .string, .classIdentifier, .id]
}
