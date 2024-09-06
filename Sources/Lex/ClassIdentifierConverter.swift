//
//  ClassIdentifierConverter.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/6/24.
//

class ClassIdentifierConverter {
    public static func convert(_ tokens: [Token]) -> [Token] {
        var classIdentifiers: [String] = Self.knownIdentifiers
        var res = tokens
        for i in 0..<tokens.count {
            if i - 1 >= 0, i + 1 < tokens.count {
                if tokens[i].type == .identifier,
                   (tokens[i - 1].type == .interface || tokens[i - 1].type == .implementation) {
                    classIdentifiers += [tokens[i].lex]
                }
                
                if tokens[i].type == .star, tokens[i + 1].type == .rightParen, tokens[i - 1].type == .identifier {
                    classIdentifiers += [tokens[i - 1].lex]
                }
            }
        }
        
        for i in 0..<res.count {
            if classIdentifiers.contains(res[i].lex) {
                res[i] = Token(type: .classIdentifier, lex: res[i].lex)
            }
        }
        
        return res
    }
    
    private static let knownIdentifiers = ["NSString", "NSInteger", "NSObject", "NSArray", "NSMutableString"]
}
