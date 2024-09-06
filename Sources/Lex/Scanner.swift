//
//  Scanner.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/28/24.
//

import Foundation

class Scanner {
    /// The source code to tokenize
    private var _sourceCode: String {
        get {
            String(self.sourceCode)
        }
        set {
            self.sourceCode = Array(newValue)
        }
    }
    
    /// The source coud to index
    private var sourceCode: [Character] = []
    
    /// The tokens
    private var tokens: [Token] = []
    
    /// The unhandled characters
    private var unhandled: [String] = []
    
    /// The current index of the lexer
    private var index: Int = 0
    
    /// Is index at the end of the source code
    private var isAtEnd: Bool { self.index >= self.sourceCode.count }
    
    public func scan(at path: String) -> [Token] {
        /// Read in the contents of the file
        self.readFile(at: path)
        
        /// Convert source code to tokens
        self.scanTokens()
        
        return self.tokens
    }
    
    /// For testing
    public func scanString(_ string: String) -> [Token] {
        self._sourceCode = string
        self.scanTokens()
        return self.tokens
    }
    
    private func readFile(at path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            self._sourceCode = content
        } catch {
            print("Error reading file at \(path): \(error.localizedDescription)")
        }
    }
    
    private func scanTokens() {
        while !self.isAtEnd {
            self.scanToken()
        }
        
        self.addToken(.EOF)
        
        self.tokens = ClassIdentifierConverter.convert(self.tokens)
    }
    
    private func scanToken() {
        let c: Character = sourceCode[index]
        self.advance()
        
        switch c {
        case "^":                       self.addToken(.carrot)
        case "_":                       self.match(expected: "_") ? self.arc() : self.addToken(.underline)
        case "#":                       self.preProcessor()
        case ".":                       self.addToken(.dot)
        case ",":                       self.addToken(.comma)
        case ";":                       self.addToken(.semicolon)
        case "(":                       self.addToken(.leftParen)
        case ")":                       self.addToken(.rightParen)
        case "{":                       self.addToken(.leftBrace)
        case "}":                       self.addToken(.rightBrace)
        case "[":                       self.addToken(.leftSquare)
        case "]":                       self.addToken(.rightSquare)
        case "*":                       self.addToken(.star)
        case "-":                       self.addToken(.minus)
        case "?":                       self.addToken(.questionMark)
        case ":":                       self.addToken(.horDots)
        case "%":                       self.addToken(.percent)
        case "+":                       self.plus()
        case "&":                       self.addToken(match(expected: "&") ? .and : .amper)
        case "|":                       self.addToken(match(expected: "|") ? .or : .pipe)
        case "=":                       self.addToken(match(expected: "=") ? .equalsEquals : .equals)
        case "!":                       self.addToken(match(expected: "=") ? .bangEquals : .bang)
        case "<":                       self.addToken(match(expected: "=") ? .lessEqual : .less)
        case ">":                       self.addToken(match(expected: "=") ? .greaterEqual : .greater)
        case "/":                       self.match(expected: "/") ? self.comment() : self.addToken(.slash)
        case "@":                       self.at()
        case let x where c.isNumber:    self.number(x)
        case let x where c.isLetter:    self.identifier(x)
        case _ where c.isWhitespace:    break
        default:                        self.addUnhandled(String(c))
        }
    }
    
    private func arc() {
        self.identifier()
    }
    
    private func preProcessor() {
        var res = ""
        
        while self.peek().isLetter {
            res += String(self.peek())
            self.advance()
        }
        
        if let preProcessor = Reserved.preProcessorWords[res] {
            self.addToken(preProcessor)
        } else {
            self.addUnhandled(res)
        }
    }
    
    private func plus() {
        if self.match(expected: "=") { self.addToken(.plusEquals) }
        else if self.match(expected: "+") { self.addToken(.plusPlus) }
        else { self.addToken(.plus) }
    }
    
    private func number(_ c: Character) {
        var res = String(c)
        
        while self.peek().isNumber {
            res += String(self.peek())
            self.advance()
        }
        
        if self.peek() == ".", self.peekNext().isNumber {
            res += String(self.peek())
            self.advance()
        }
        
        while self.peek().isNumber {
            res += String(self.peek())
            self.advance()
        }
        
        self.addToken(.number, lex: res)
    }
    
    private func at() {
        if self.match(expected: "\"") { self.string() }
        else if self.match(expected: "[") { self.addToken(.arrayStart) }
        else if self.peek().isLetter { self.identifier() }
        else { self.addToken(.at) }
    }
    
    private func string() {
        var res = ""
        
        while self.peek() != "\"", !self.isAtEnd {
            res += String(self.peek())
            self.advance()
        }
        
        /// Consume that final `"`
        self.advance()
        
        self.addToken(.string, lex: res)
    }
    
    private func identifier(_ c: Character? = nil) {
        var res = if let c = c { String(c) } else { "" }
        
        while self.peek().isLetter || self.peek().isNumber {
            res += String(self.peek())
            self.advance()
        }
        
        if let keyword = Reserved.words[res] {
            self.addToken(keyword, lex: res)
        } else {
            self.addToken(.identifier, lex: res)
        }
    }
    
    private func comment() {
        while self.peek() != "\n", !self.isAtEnd { self.advance() }
    }
    
    private func match(expected: Character) -> Bool {
        guard !self.isAtEnd else { return false }
        
        if sourceCode[index] != expected { return false }
        
        self.advance()
        return true
    }
    
    private func peek() -> Character {
        guard !self.isAtEnd else { return "\0" }
        return self.sourceCode[index]
    }
    
    private func peekNext() -> Character {
        guard index + 1 < self.sourceCode.count else { return "\0" }
        return self.sourceCode[index + 1]
    }
    
    private func advance() {
        self.index += 1
    }
    
    private func addToken(_ type: TokenType) {
        self.tokens += [Token(type: type)]
    }
    
    private func addToken(_ type: TokenType, lex: String) {
        self.tokens += [Token(type: type, lex: lex)]
    }
    
    private func addUnhandled(_ string: String) {
        self.unhandled += [string]
    }
    
    private func printTokens() {
        print("=== Tokens ===")
        print(tokens.reduce("", { res, token in
            res + "[\(token.type): \(token.lex)], "
        }))
    }
    
    private func printUnhandled() {
        print("=== Unhandled ===")
        guard !self.unhandled.isEmpty else {
            print("NONE\n")
            return
        }
        print(unhandled.reduce("", { res, char in res + char + " " }))
        print("")
    }
}
