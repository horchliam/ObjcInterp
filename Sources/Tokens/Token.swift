//
//  Token.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/28/24.
//

import Foundation

class Token {
    let type: TokenType
    let lex: String
    
    init(type: TokenType, 
         lex: String) {
        self.type = type
        self.lex = lex
    }
    
    init(type: TokenType) {
        self.type = type
        self.lex = type.rawValue
    }
}
