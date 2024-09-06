//
//  Resolver.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/5/24.
//

enum FunctionType {
    case none, function, method
}

enum CurScope {
    case classDef, classImpl, other
}

class Resolver: StmtVisitor, ExprVisitor {
    private final let interpreter: Interpreter
    private final var scopes: [[String]] = [[]]
    private final var curClass: String? = nil
    private final var curScope: CurScope = .other
    private final var classScope: [String : [String]] = [:]
    
    init(interpreter: Interpreter) {
        self.interpreter = interpreter
    }
    
    func visitAssignExpr(_ expr: Expr.Assign) throws {
        self.resolve(expr.value)
        self.resolveLocal(expr: expr, name: expr.name)
    }
    
    func visitBinaryExpr(_ expr: Expr.Binary) throws {
        self.resolve(expr.left)
        self.resolve(expr.right)
    }
    
    func visitGroupingExpr(_ expr: Expr.Grouping) throws {
        self.resolve(expr.expr)
    }
    
    func visitLiteralExpr(_ expr: Expr.Literal) throws {}
    
    func visitArrayExpr(_ expr: Expr.Array) throws {
        expr.contents.forEach { self.resolve($0) }
    }
    
    func visitUnaryExpr(_ expr: Expr.Unary) throws {
        self.resolve(expr.right)
    }
    
    func visitVariableExpr(_ expr: Expr.Variable) throws {
        self.resolveLocal(expr: expr, name: expr.name)
    }
    
    func visitLogicalExpr(_ expr: Expr.Logical) throws {
        self.resolve(expr.left)
        self.resolve(expr.right)
    }
    
    func visitTernaryExpr(_ expr: Expr.Ternary) throws {
        self.resolve(expr.condition)
        self.resolve(expr.thenExpr)
        self.resolve(expr.elseExpr)
    }
    
    func visitArrayGetExpr(_ expr: Expr.ArrayGet) throws {
        self.resolve(expr.object)
        self.resolve(expr.index)
    }
    
    func visitArraySetExpr(_ expr: Expr.ArraySet) throws {
        self.resolve(expr.value)
        self.resolve(expr.object)
        self.resolve(expr.index)
    }
    
    func visitGetExpr(_ expr: Expr.Get) throws { 
        self.resolve(expr.object)
    }
    
    func visitSetExpr(_ expr: Expr.Set) throws {
        self.resolve(expr.value)
        self.resolve(expr.object)
    }
    
    func visitSelfyExpr(_ expr: Expr.Selfy) throws {
        self.resolveLocal(expr: expr, name: expr.keyword)
    }
    
    func visitSuperyExpr(_ expr: Expr.Supery) throws {
        self.resolveLocal(expr: expr, name: expr.keyword)
    }
    
    func visitCallExpr(_ expr: Expr.Call) throws {
        self.resolve(expr.callee)
        expr.args.forEach { self.resolve($0) }
    }
    
    func visitMyTypeExpr(_ expr: Expr.MyType) throws {}
    
    func visitBlockExprTypeExpr(_ expr: Expr.BlockExprType) throws {
        if let name = expr.name { self.define(name) }
    }
    
    func visitBlockExprExpr(_ expr: Expr.BlockExpr) throws {
        self.resolveBlock(expr)
    }
    
    func visitBlockStmt(_ stmt: Stmt.Block) throws {
        self.beginScope()
        self.resolve(stmts: stmt.statements)
        self.endScope()
    }
    
    func visitExpressionStmt(_ stmt: Stmt.Expression) throws { 
        self.resolve(stmt.expression)
    }
    
    func visitIfStmt(_ stmt: Stmt.If) throws {
        self.resolve(stmt.condition)
        self.resolve(stmt.thenBranch)
        self.resolve(stmt.elseBranch)
    }
    
    func visitVarStmt(_ stmt: Stmt.Var) throws {
        if let curClass = self.curClass, self.curScope == .classDef {
            self.defineClassDef(klass: curClass, name: stmt.name.lex)
        } else {
            self.define(stmt.name)
        }
        self.resolve(stmt.initializer)
    }
    
    func visitReturnStmt(_ stmt: Stmt.Return) throws {
        self.resolve(stmt.value)
    }
    
    func visitWhileStmt(_ stmt: Stmt.While) throws {
        self.resolve(stmt.condition)
        self.resolve(stmt.body)
    }
    
    func visitForStmt(_ stmt: Stmt.For) throws {
        self.resolve(stmt.initializer)
        self.resolve(stmt.condition)
        self.resolve(stmt.change)
        self.resolve(stmt.body)
    }
    
    func visitPrintStmt(_ stmt: Stmt.Print) throws {
        self.resolve(stmt.value)
    }
    
    func visitFunctionStmt(_ stmt: Stmt.Function) throws {
        self.define(stmt.name)
        self.resolveFunction(stmt)
    }
    
    func visitClassDefStmt(_ stmt: Stmt.ClassDef) throws { 
        self.define(stmt.name)
        if let superclass = stmt.superclass {
            self.resolve(superclass)
        }
        self.beginClassScope(name: stmt.name.lex, type: .classDef)
        for property in stmt.properties {
            self.resolve(property)
        }
        self.endClassScope()
    }
    
    func visitClassImplStmt(_ stmt: Stmt.ClassImpl) throws {
        // Defined in header
        //self.define(stmt.name)
        
        self.beginScope()
        self.beginClassScope(name: stmt.name.lex, type: .classImpl)
        self.define("self")
        self.define("super")
        
        for method in stmt.methods {
            self.resolveFunction(method)
        }
        
        self.endScope()
        self.endClassScope()
    }
    
    func visitTypeDefStmt(_ stmt: Stmt.TypeDef) throws {}
    
    public func resolve(stmts: [Stmt?]) {
        for stmt in stmts {
            self.resolve(stmt)
        }
    }
    
    private func resolve(_ stmt: Stmt?) {
        do {
            try stmt?.accept(visitor: self)
        } catch { }
    }
    
    private func resolve(_ expr: Expr?) {
        do {
            try expr?.accept(visitor: self)
        } catch { }
    }
    
    private func beginScope() {
        self.scopes.append([])
    }
    
    private func endScope() {
        self.scopes.removeLast()
    }
    
    private func beginClassScope(name: String, type: CurScope) {
        self.curClass = name
        self.curScope = type
    }
    
    private func endClassScope() {
        self.curClass = nil
        self.curScope = .other
    }
    
    private func currentScope() -> [String] {
        return self.scopes.last!
    }
    
    private func define(_ name: Token) {
        guard self.scopes.count > 0, !self.scopes[self.scopes.count - 1].contains(name.lex) else { return }
        self.scopes[self.scopes.count - 1] += [name.lex]
    }
    
    private func define(_ name: String) {
        guard self.scopes.count > 0, !self.scopes[self.scopes.count - 1].contains(name) else { return }
        self.scopes[self.scopes.count - 1] += [name]
    }
    
    // For implicit self reference
    private func defineClassDef(klass: String, name: String) {
        self.classScope[klass, default: []] += [name]
    }
    
    private func resolveLocal(expr: Expr, name: Token) {
        if let curClass = self.curClass, let _ = self.classScope[curClass], self.curScope == .classImpl {
            self.interpreter.resolve(expr: expr, depth: 1)
        }
        
        for (i, scope) in scopes.reversed().enumerated() {
            if scope.contains(name.lex) {
                self.interpreter.resolve(expr: expr, depth: i)
                return
            }
        }
    }
    
    private func resolveFunction(_ function: Stmt.Function) {
        self.beginScope()
        for param in function.params {
            self.define(param.1)
        }
        self.resolve(stmts: function.body)
        self.endScope()
    }
    
    private func resolveBlock(_ block: Expr.BlockExpr) {
        self.beginScope()
        for param in block.params {
            self.define(param.1)
        }
        self.resolve(stmts: block.body)
        self.endScope()
    }
}
