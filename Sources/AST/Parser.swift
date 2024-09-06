//
//  Parser.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/30/24.
//

import Foundation

class Parser {
    private var tokens: [Token] = []
    private var index: Int = 0
    private var isAtEnd: Bool { self.peek().type == .EOF }
    private var error: Bool = false
    private var typeDefs: [String] = []
    
    public func parse() -> [Stmt] {
        var statements: [Stmt] = []
        while !self.isAtEnd && !error {
            statements += [self.start()]
        }
        
        if error {
            self.printRemainingTokens()
        }
        
        return statements
    }
    
    public func setTokens(_ tokens: [Token]) {
        self.tokens = tokens
    }
    
    private func printRemainingTokens() {
        var res = "Remaining tokens after error...\n"
        for token in tokens[index...] {
            res += "[\(token.type): \(token.lex)], "
        }
        
        print(res + "\n")
    }
    
    private func start() -> Stmt {
        if let type = self.type() {
            return self.decleration(type)
        }
        
        return self.statement()
    }
    
    private func decleration(_ type: Expr.MyType) -> Stmt {
        var name: Token!
        if let blockType = type.exprType as? Expr.BlockExprType {
            name = blockType.name
        } else {
            name = self.consume(.identifier)!
        }
        
        if self.match(.leftParen) {
            return self.funcDecleration(name, type)
        } else {
            return self.varDecleration(name, type)
        }
    }
    
    private func funcDecleration(_ name: Token, _ type: Expr.MyType) -> Stmt {
        var params: [(Expr.MyType, Token)] = []
        
        if !self.check(.rightParen) {
            repeat {
                if let param = self.functionParam() { params += [param] }
            } while (self.match(.comma))
        }
        
        self.consume(.rightParen)
        if self.match(.semicolon) {
            return Stmt.Function(name: name, params: params, body: [], isStatic: false)
        } else {
            self.consume(.leftBrace)
            return Stmt.Function(name: name, params: params, body: self.blockStatmenets(), isStatic: false)
        }
    }
    
    private func varDecleration(_ name: Token, _ type: Expr.MyType) -> Stmt {
        var initializer: Expr? = nil
        if self.match(.equals) {
            initializer = self.expression()
        }
        
        self.consume(.semicolon)
        return Stmt.Var(type: type, name: name, initializer: initializer)
    }
    
    private func statement() -> Stmt {
        if self.match(.leftBrace) { return self.block() }
        if self.match(.If) { return self.ifStatement() }
        if self.match(.Return) { return self.returnStatement()}
        if self.match(.While) { return self.whileStatement() }
        if self.match(.For) { return self.forStatement() }
        if self.match(.print) { return self.printStatement() }
        if self.match(.interface) { return self.classDecleration() }
        if self.match(.implementation) { return self.classImplementation() }
        if self.match(.typeDef) { return self.typeDef() }
        return self.expressionStatement()
    }
    
    private func typeDef() -> Stmt {
        let type = self.type()!
        self.consume(.semicolon)
        if let blockType = type.exprType as? Expr.BlockExprType {
            let name = blockType.name!
            self.typeDefs += [name.lex]
            return Stmt.TypeDef(name: name, newType: type)
        }
        
        return Stmt.TypeDef(name: .init(type: .identifier, lex: "ERROR"), newType: type) // Error
    }
    
    private func classDecleration() -> Stmt {
        let name = self.consume(.classIdentifier)!
        var superclass: Expr.Variable? = nil
        
        // Inheritance
        if self.match(.horDots) {
            superclass = Expr.Variable(name: self.consume(.classIdentifier)!)
        }
        
        var methods: [Stmt.Function] = []
        var properties: [Stmt.Var] = []
        while !self.check(.end) && !self.isAtEnd {
            if self.match(types: [.minus, .plus]) {
                methods += [self.classFunction()]
            } else if self.match(.property) {
                properties += [self.classPropertyDecleration()]
            }
        }
        
        self.consume(.end)
        return Stmt.ClassDef(name: name, superclass: superclass, methods: methods, properties: properties)
    }
    
    private func classImplementation() -> Stmt {
        let name = self.consume(.classIdentifier)!
        
        // Extension
        if self.match(.leftParen) {
            self.maybeConsume(.identifier)
            self.maybeConsume(.classIdentifier)
            self.consume(.rightParen)
        }
        
        var methods: [Stmt.Function] = []
        while !self.check(.end) && !self.isAtEnd {
            if self.match(types: [.minus, .plus]) {
                methods += [self.classFunction()]
            }
        }
        
        self.consume(.end)
        return Stmt.ClassImpl(name: name, methods: methods, properties: [])
    }
    
    private func classFunction() -> Stmt.Function {
        let isStatic = self.previous().type == .plus
        let funcName = self.consumeFunctionParamTypeAndName().1
        var params: [(Expr.MyType, Token)] = []
        
        if self.match(.horDots) {
            params += [self.consumeFunctionParamTypeAndName()]
            while self.match(.identifier) {
                self.consume(.horDots)
                params += [self.consumeFunctionParamTypeAndName()]
            }
        }
        
        var body: [Stmt] = []
        if self.match(.leftBrace) {
            body = self.blockStatmenets()
        } else {
            self.consume(.semicolon)
        }
        
        return Stmt.Function(name: funcName, params: params, body: body, isStatic: isStatic)
    }
    
    @discardableResult
    private func consumeFunctionParamTypeAndName() -> (Expr.MyType, Token) {
        self.consume(.leftParen)
        let returnType = self.type()!
        self.consume(.rightParen)
        let name = self.consume(.identifier)!
        return (returnType, name)
    }
    
    private func classPropertyDecleration() -> Stmt.Var {
        self.maybeConsumePropertyAttributes()
        
        let type = self.type()!
        // If a pointer
        self.maybeConsume(.star)
        let name = self.consumeOfTypes([.identifier, .classIdentifier])!
        return self.varDecleration(name, type) as! Stmt.Var
    }
    
    private func maybeConsumePropertyAttributes() {
        self.maybeConsume(.leftParen)
        repeat {
            self.maybeConsume(.identifier)
        } while (self.match(.comma))
        self.maybeConsume(.rightParen)
    }
    
    /// Note: need to consume `leftBrace` before this method
    private func block() -> Stmt {
        let statements = self.blockStatmenets()
        /// `;` may or may not terminate the block.
        ///  Consume if present.
        self.maybeConsume(.semicolon)
        return Stmt.Block(statements: statements)
    }
    
    private func blockStatmenets() -> [Stmt] {
        var statements: [Stmt] = []
        
        while !self.check(.rightBrace) {
            statements += [self.start()]
        }
        
        self.consume(.rightBrace)
        return statements
    }
    
    private func whileStatement() -> Stmt {
        self.consume(.leftParen)
        let condition = self.expression()
        self.consume(.rightParen)
        
        var body: Stmt? = nil
        if self.match(.leftBrace) {
            body = self.block()
        } else {
            body = self.statement()
        }
        
        return Stmt.While(condition: condition, body: body!)
    }
    
    private func forStatement() -> Stmt {
        self.consume(.leftParen)
        
        var initializer: Stmt? = nil
        if self.match(.semicolon) {
            initializer = nil
        } else if let type = self.type() {
            initializer = self.decleration(type)
        } else {
            initializer = self.expressionStatement()
        }
        
        var condition: Expr? = nil
        if self.match(.semicolon) {
            condition = nil
        } else {
            condition = self.expression()
            self.consume(.semicolon)
        }
        
        var change: Expr? = nil
        if !self.check(.rightParen) {
            change = self.expression()
        }
        self.consume(.rightParen)
        
        var body: Stmt? = nil
        if self.match(.leftBrace) {
            body = self.block()
        } else {
            body = self.statement()
        }
        
        return Stmt.For(initializer: initializer, condition: condition, change: change, body: body!)
    }
    
    private func ifStatement() -> Stmt {
        self.consume(.leftParen)
        let condition = self.expression()
        self.consume(.rightParen)
        
        var thenBranch: Stmt? = nil
        if self.match(.leftBrace) {
            thenBranch = self.block()
        } else {
            thenBranch = self.statement()
        }
        
        var elseBranch: Stmt? = nil
        if self.match(.Else) {
            if self.match(.leftBrace) {
                // else
                elseBranch = self.block()
            } else {
                // else if
                elseBranch = self.statement()
            }
        }
        
        return Stmt.If(condition: condition, thenBranch: thenBranch!, elseBranch: elseBranch)
    }
    
    private func returnStatement() -> Stmt {
        var returnValue: Expr? = nil
        if !self.check(.semicolon) {
            returnValue = self.expression()
        }
        
        self.consume(.semicolon)
        return Stmt.Return(value: returnValue)
    }
    
    private func printStatement() -> Stmt {
        let value = self.expression()
        self.consume(.semicolon)
        return Stmt.Print(value: value)
    }
    
    private func expressionStatement() -> Stmt {
        let expr = self.expression()
        self.maybeConsume(.semicolon) /// Consume the statement terminating `;`
        return Stmt.Expression(expression: expr)
    }
    
    private func expression() -> Expr {
        let expr = self.assignment()
        
        if self.match(.questionMark) {
            let thenExpr = self.expression()
            self.consume(.horDots)
            let elseExpr = self.expression()
            return Expr.Ternary(condition: expr, thenExpr: thenExpr, elseExpr: elseExpr)
        }
        
        return expr
    }
    
    private func assignment() -> Expr {
        let expr = self.plusPlus()
        
        if self.match(types: [.equals, .plusEquals]) {
            let oper = self.previous()
            let right = self.assignment()
            
            if let expr = expr as? Expr.Variable {
                let name = expr.name
                return Expr.Assign(name: name, oper: oper, value: right)
            } else if let expr = expr as? Expr.Get {
                return Expr.Set(object: expr.object, name: expr.name, value: right, oper: oper)
            } else if let expr = expr as? Expr.ArrayGet {
                return Expr.ArraySet(object: expr.object, index: expr.index, value: right, oper: oper)
            }
            
            // ERROR
            self.error = true
            return Expr.Literal(value: "ERROR")
        }
        
        return expr
    }
    
    private func plusPlus() -> Expr {
        let expr = self.or()
        
        if self.match(.plusPlus) {
            let oper = self.previous()
            
            if let expr = expr as? Expr.Variable {
                let name = expr.name
                return Expr.Assign(name: name, oper: oper, value: Expr.Literal(value: 1.0))
            } else if let expr = expr as? Expr.Get {
                return Expr.Set(object: expr.object, name: expr.name, value: Expr.Literal(value: 1.0), oper: oper)
            }
        }
        
        return expr
    }
    
    private func or() -> Expr {
        var expr = self.and()
        
        while match(.or) {
            let oper = self.previous()
            let right = self.and()
            expr = Expr.Logical(left: expr, oper: oper, right: right)
        }
        
        return expr
    }
    
    private func and() -> Expr {
        var expr = self.equality()
        
        while match(.and) {
            let oper = self.previous()
            let right = self.equality()
            expr = Expr.Logical(left: expr, oper: oper, right: right)
        }
        
        return expr
    }
    
    private func equality() -> Expr {
        var expr = self.comparison()
        
        while self.match(types: [.equalsEquals, .bangEquals]) {
            let oper = self.previous()
            let right = self.comparison()
            expr = Expr.Binary(left: expr, oper: oper, right: right)
        }
        
        return expr
    }
    
    private func comparison() -> Expr {
        var expr = self.term()
        
        while self.match(types: [.less, .greater, .greaterEqual, .lessEqual]) {
            let oper = self.previous()
            let right = self.term()
            expr = Expr.Binary(left: expr, oper: oper, right: right)
        }
        
        return expr
    }
    
    private func term() -> Expr {
        var expr = self.factor()
        
        while self.match(types: [.plus, .minus]) {
            let oper = self.previous()
            let right = self.factor()
            expr = Expr.Binary(left: expr, oper: oper, right: right)
        }
        
        return expr
    }
    
    private func factor() -> Expr {
        var expr = self.unary()
        
        if self.match(.leftSquare) {
            return self.indexArray(expr)
        }
        
        while self.match(types: [.slash, .star, .percent]) {
            let oper = self.previous()
            let right = self.unary()
            expr = Expr.Binary(left: expr, oper: oper, right: right)
        }
        
        return expr
    }
    
    private func indexArray(_ expr: Expr) -> Expr {
        var expr = expr
        repeat {
            let index = self.call()
            self.consume(.rightSquare)
            expr = Expr.ArrayGet(object: expr, index: index)
        } while (self.match(.leftSquare))
        return expr
    }
    
    private func unary() -> Expr {
        while self.match(types: [.bang, .minus]) {
            let oper = self.previous()
            let right = self.unary()
            return Expr.Unary(oper: oper, right: right)
        }
        
        return self.blockExpr()
    }
    
    private func blockExpr() -> Expr {
        if self.match(.carrot) {
            let returnType = self.type()
            var params: [(Expr.MyType, Token)] = []
            if self.match(.leftParen) {
                repeat {
                    if let param = self.functionParam() { params += [param] }
                } while (self.match(.comma))
                self.consume(.rightParen)
            }
            self.consume(.leftBrace)
            let body = self.blockStatmenets()
            return Expr.BlockExpr(returnType: returnType, params: params, body: body)
        }
        
        return self.call()
    }
    
    private func call() -> Expr {
        var expr = objectivecCall()
        
        while true {
            if self.match(.leftParen) { expr = self.finishCall(expr) }
            else if self.match(.dot) { expr = Expr.Get(object: expr, name: self.consume(.identifier)!) }
            else { break }
        }
        
        return expr
    }
    
    private func objectivecCall() -> Expr {
        if self.match(.leftSquare) {
            let expr = self.factor()
            let function = self.consume(.identifier)!
            
            var args: [Expr] = []
            
            if self.match(.horDots) {
                args += [self.expression()]
                while (!self.check(.rightSquare)) {
                    self.consume(.identifier)
                    self.consume(.horDots)
                    args += [self.expression()]
                }
            }
            
            self.consume(.rightSquare)
            
            let get = Expr.Get(object: expr, name: function)
            return Expr.Call(callee: get, args: args)
        }
        
        return self.primary()
    }
    
    private func finishCall(_ expr: Expr) -> Expr {
        var args: [Expr] = []
        
        if (!self.check(.rightParen)) {
            repeat {
                args += [self.expression()]
            } while (self.match(.comma))
        }
        
        self.consume(.rightParen)
        return Expr.Call(callee: expr, args: args)
    }
    
    private func functionParam() -> (Expr.MyType, Token)? {
        if let type = self.type() {
            if let blockType = type.exprType as? Expr.BlockExprType {
                return (type, blockType.name!)
            } else {
                let name = self.maybeConsume(.identifier)!
                
                return (type, name)
            }
        }
        return nil
    }
    
    private func type() -> Expr.MyType? {
        if self.isVariableType() {
            let returnType = self.previous()
            // If a pointer
            self.maybeConsume(.star)
            if self.peek().type == .leftParen, self.doublePeek().type == .carrot {
                return self.blockExprType(Expr.MyType(type: returnType, exprType: nil))
            }
            
            return Expr.MyType(type: returnType, exprType: nil)
        }
        
        return nil
    }
    
    private func isVariableType() -> Bool {
        if self.match(types: TokenType.variableTypes) {
            return true
        }
        
        if self.typeDefs.contains(self.peek().lex) {
            self.advance()
            return true
        }
        
        return false
    }
    
    private func blockExprType(_ outerReturnType: Expr.MyType) -> Expr.MyType? {
        struct BlockType {
            var name: Token?
            var params: [Expr.MyType] = []
            var returnType: Expr.MyType = .init(type: nil, exprType: nil)
        }
        
        var blocks: [BlockType] = [.init(returnType: outerReturnType)]
        var curBlock = 0
        self.consume(.leftParen)
        self.consume(.carrot)
        
        while curBlock >= 0 {
            if self.peek().type == .leftParen, self.doublePeek().type == .carrot {
                blocks += [.init()]
                curBlock += 1
                
                self.consume(.leftParen)
                self.consume(.carrot)
            }
            
            let name = self.maybeConsume(.identifier)
            var params: [Expr.MyType] = []
            if self.match(.rightParen) {
                self.consume(.leftParen)
                repeat {
                    if let param = self.type() {
                        params += [param]
                    }
                } while(self.match(.comma))
                self.consume(.rightParen)
                
                blocks[curBlock].name = name
                blocks[curBlock].params = params
                curBlock -= 1
            }
        }
        
        var curBlockExpr: Expr.MyType? = nil
        if let firstBlock = blocks.first {
            curBlockExpr = Expr.MyType(type: nil, exprType: Expr.BlockExprType(returnType: firstBlock.returnType, name: firstBlock.name, params: firstBlock.params))
            
            for block in blocks.dropFirst() {
                curBlockExpr = Expr.MyType(type: nil, exprType: Expr.BlockExprType(returnType: curBlockExpr!, name: block.name, params: block.params))
            }
        }
        return curBlockExpr
    }
    
    private func primary() -> Expr {
        if self.match(.number) {
            return Expr.Literal(value: Double(self.previous().lex))
        } else if self.match(.string) {
            return Expr.Literal(value: self.previous().lex)
        }else if self.match(.leftParen) {
            let expr = self.expression()
            self.consume(.rightParen) /// Consume the `)`
            return Expr.Grouping(expr: expr)
        } else if self.match(.arrayStart) {
            return self.array()
        } else if self.match(.yes) {
            return Expr.Literal(value: true)
        } else if self.match(.no) {
            return Expr.Literal(value: false)
        } else if self.match(.null) {
            return Expr.Literal(value: nil)
        } else if self.match(types: [.classIdentifier, .identifier]) {
            return Expr.Variable(name: self.previous())
        } else if self.match(.selfy) {
            return Expr.Selfy(keyword: self.previous())
        } else if self.match(.supery) {
            return Expr.Supery(keyword: self.previous())
        }
        
        // Nothing
        return Expr.Literal(value: nil)
    }
    
    private func array() -> Expr {
        var contents: [Expr] = []
        repeat {
            contents += [self.expression()]
        } while (self.match(.comma))
        
        self.consume(.rightSquare)
        
        return Expr.Array(contents: contents)
    }
    
    @discardableResult
    private func consumeOfTypes(_ tokens: [TokenType]) -> Token? {
        for token in tokens {
            if self.check(token) {
                self.advance()
                return self.previous()
            }
        }
        
        // ERROR
        self.error = true
        return nil
    }
    
    @discardableResult
    private func consume(_ token: TokenType) -> Token? {
        if self.check(token) {
            self.advance()
            return self.previous()
        }
        
        // ERROR
        self.error = true
        return nil
    }
    
    @discardableResult
    private func maybeConsume(_ token: TokenType) -> Token? {
        if self.check(token) {
            self.advance()
            return self.previous()
        }
        
        return nil
    }
    
    private func match(types: [TokenType]) -> Bool {
        for type in types {
            if self.match(type) { return true }
        }
        
        return false
    }
    
    private func match(_ type: TokenType) -> Bool {
        if self.check(type) {
            self.advance()
            return true
        }
        
        return false
    }
    
    private func check(_ type: TokenType) -> Bool {
        guard !self.isAtEnd else { return false }
        return self.peek().type == type
    }
    
    private func advance() {
        self.index += 1
    }
    
    private func peek() -> Token {
        self.tokens[index]
    }
    
    private func doublePeek() -> Token {
        self.tokens[index + 1]
    }
    
    private func previous() -> Token {
        self.tokens[index - 1]
    }
    
    private func previousPrevious() -> Token {
        self.tokens[index - 2]
    }
}
