//
//  ASTPrinter.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/30/24.
//

import Foundation

class ASTPrinter: ExprVisitor, StmtVisitor {    
    public func print(stmts: [Stmt]) -> String {
        var res = "=== AST ===\n"
        
        do {
            try stmts.forEach { try res += $0.accept(visitor: self) + "\n" }
        } catch {}
        
        return res
    }
    
    public func print(expr: Expr) -> String {
        do {
            return try "=== AST ===\n" + expr.accept(visitor: self)
        } catch {
            return ""
        }
    }
    
    /// For testing
    public func getString(for stmts: [Stmt]) -> String {
        do {
            return try stmts.reduce("") { try $0 + $1.accept(visitor: self) }
        } catch {
            return ""
        }
    }
    
    func visitAssignExpr(_ expr: Expr.Assign) throws -> String {
        let specificOper = expr.oper.type == .equals ? nil : expr.oper
        return parenthesize(name: "assign", additionalTokens: [expr.name, specificOper], exprs: [expr.value])
    }
    
    func visitTernaryExpr(_ expr: Expr.Ternary) throws -> String {
        return parenthesize(name: "ternary", exprs: [expr.condition, expr.thenExpr, expr.elseExpr])
    }
    
    func visitArrayGetExpr(_ expr: Expr.ArrayGet) throws -> String {
        return parenthesize(name: "arrayGet", other: [expr.object, expr.index])
    }
    
    func visitArraySetExpr(_ expr: Expr.ArraySet) throws -> String {
        return parenthesize(name: "arraySet", other: [expr.object, expr.index, expr.value])
    }

    func visitGetExpr(_ expr: Expr.Get) throws -> String {
        return parenthesize(name: "get", additionalTokens: [expr.name], other: [expr.object])
    }
    
    func visitSetExpr(_ expr: Expr.Set) throws -> String {
        return parenthesize(name: "set", additionalTokens: [expr.name, expr.oper], other: [expr.object, expr.value])
    }
    
    func visitSelfyExpr(_ expr: Expr.Selfy) throws -> String {
        return "self"
    }
    
    func visitSuperyExpr(_ expr: Expr.Supery) throws -> String {
        return "super"
    }
    
    func visitLogicalExpr(_ expr: Expr.Logical) throws -> String {
        return parenthesize(name: expr.oper.lex, exprs: [expr.left, expr.right])
    }
    
    public func visitBinaryExpr(_ expr: Expr.Binary) throws -> String {
        return parenthesize(name: expr.oper.lex, exprs: [expr.left, expr.right])
    }
    
    func visitArrayExpr(_ expr: Expr.Array) throws -> String {
        return parenthesize(name: "array", other: expr.contents)
    }
    
    public func visitGroupingExpr(_ expr: Expr.Grouping) throws -> String {
        return parenthesize(name: "group", other: [expr.expr])
    }
    
    public func visitLiteralExpr(_ expr: Expr.Literal) throws -> String {
        if let number = expr.value as? Double, number.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(format: "%.0f", number)
        }
        
        return String(describing: expr.value ?? "nil")
    }
    
    public func visitUnaryExpr(_ expr: Expr.Unary) throws -> String {
        return parenthesize(name: expr.oper.lex, exprs: [expr.right])
    }
    
    public func visitVariableExpr(_ expr: Expr.Variable) throws -> String {
        return expr.name.lex
    }
    
    func visitCallExpr(_ expr: Expr.Call) throws -> String {
        let name = try expr.callee.accept(visitor: self)
        return parenthesize(name: "call.\(name)", other: expr.args)
    }
    
    func visitMyTypeExpr(_ expr: Expr.MyType) throws -> String {
        if let token = expr.type {
            return token.lex
        } else {
            return try expr.exprType?.accept(visitor: self) ?? ""
        }
    }
    
    func visitBlockExprTypeExpr(_ expr: Expr.BlockExprType) throws -> String {
        parenthesize(name: "blockType", other: [expr.returnType] + expr.params)
    }
    
    func visitBlockExprExpr(_ expr: Expr.BlockExpr) throws -> String {
        parenthesize(name: "blockExpr", other: [expr.returnType] + expr.params.map { $0.1 } + expr.body)
    }
    
    func visitBlockStmt(_ stmt: Stmt.Block) throws -> String {
        return parenthesize(name: "block", stmts: stmt.statements)
    }
    
    func visitIfStmt(_ stmt: Stmt.If) throws -> String {
        return parenthesize(name: "if", exprs: [stmt.condition], stmts: [stmt.thenBranch, stmt.elseBranch])
    }
    
    func visitReturnStmt(_ stmt: Stmt.Return) throws -> String {
        return parenthesize(name: "return", exprs: [stmt.value])
    }
    
    public func visitExpressionStmt(_ stmt: Stmt.Expression) throws -> String {
        return parenthesize(skip: true, exprs: [stmt.expression])
    }
    
    func visitVarStmt(_ stmt: Stmt.Var) throws -> String {
        let exprs = stmt.initializer == nil ? [] : [stmt.initializer!]
        return parenthesize(name: "varStmt", other: [stmt.type, stmt.name] + exprs)
    }
    
    func visitWhileStmt(_ stmt: Stmt.While) throws -> String {
        return parenthesize(name: "while", exprs: [stmt.condition], stmts: [stmt.body])
    }
    
    func visitForStmt(_ stmt: Stmt.For) throws -> String {
        return parenthesize(name: "for", other: [stmt.initializer, stmt.condition, stmt.change, stmt.body])
    }
    
    func visitFunctionStmt(_ stmt: Stmt.Function) throws -> String {
        let name = stmt.name.lex
        return parenthesize(name: "function.\(name)", additionalTokens: stmt.params.map { $0.1 }, other: stmt.body)
    }
    
    func visitClassDefStmt(_ stmt: Stmt.ClassDef) throws -> String {
        return parenthesize(name: "define \(stmt.name.lex)", other: stmt.methods + stmt.properties)
    }
    
    func visitClassImplStmt(_ stmt: Stmt.ClassImpl) throws -> String {
        return parenthesize(name: "implement \(stmt.name.lex)", other: stmt.methods + stmt.properties)
    }
    
    func visitPrintStmt(_ stmt: Stmt.Print) throws -> String {
        return parenthesize(name: "print", other: [stmt.value])
    }
    
    func visitTypeDefStmt(_ stmt: Stmt.TypeDef) throws -> String {
        return parenthesize(name: "typedef", other: [stmt.name, stmt.newType])
    }
    
    private func parenthesize(skip: Bool = false,
                              name: String = "",
                              additionalTokens: [Token?] = [],
                              other: [Any?] = [],
                              exprs: [Expr?] = [],
                              stmts: [Stmt?] = []) -> String {
        var res = ""
        
        if skip {
            for expr in exprs {
                do {
                    try res += expr?.accept(visitor: self) ?? ""
                } catch { }
            }
            
            return res
        }
        
        res += "(\(name)"
        res += additionalTokens.reduce("") {
            guard let token = $1 else { return $0 }
            return $0 + " " + token.lex
        }
        
        for case let entry? in other {
            res += " "
            if let expr = entry as? Expr {
                do {
                    try res += expr.accept(visitor: self)
                } catch {}
            } else if let stmt = entry as? Stmt {
                do {
                    try res += stmt.accept(visitor: self)
                } catch {}
            } else if let token = entry as? Token {
                res += token.lex
            }
        }
        
        for case let expr? in exprs {
            res += " "
            do {
                try res += expr.accept(visitor: self)
            } catch {}
        }
        
        for case let stmt? in stmts {
            res += " "
            do {
                try res += stmt.accept(visitor: self)
            } catch {}
        }
        
        res += ")"
        
        return res
    }
}
