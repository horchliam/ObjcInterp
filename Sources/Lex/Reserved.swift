//
//  Reserved.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/29/24.
//

struct Reserved {
    static let words: [String : TokenType] = [
        "int": .int,
        "if": .If,
        "else": .Else,
        "return": .Return,
        "BOOL": .bool,
        "while": .While,
        "for": .For,
        "print": .print,
        "void": .void,
        "string": .string,
        "interface": .interface,
        "end": .end,
        "implementation": .implementation,
        "property": .property,
        "YES": .yes,
        "NO": .no,
        "nil": .null,
        "self": .selfy,
        "super": .supery,
        "weak": .weak,
        "id": .id,
        "typedef": .typeDef
    ]
    
    static let preProcessorWords: [String : TokenType] = [
        "include": .include,
        "define": .define,
        "undef": .undef,
        "ifdef": .ifdef,
        "else": .elsePre,
        "endif": .endif,
        "elseif": .elseifPre,
        "pragma": .pragma,
        "error": .error,
        "warning": .warning,
        "import": .importPre
    ]
}
