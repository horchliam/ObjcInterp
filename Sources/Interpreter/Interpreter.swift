//
//  Interpreter.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/1/24.
//

import Foundation

enum ControlFlow: Error {
    case functionReturn(Any?)
}

class Interpreter: ExprVisitor, StmtVisitor {
    static private let makeNativeFunctions = { () -> Environment in
        var globalEnvironment = Environment()
        
        class ClockCallable: Callable, CustomDebugStringConvertible {
            var debugDescription: String { "<global-function clock>" }
            
            func call(interpret: Interpreter, args: [Any?]) -> Any? {
                return Date().timeIntervalSince1970 as Double
            }
        }
        
        class ArrayCallable: Callable, CustomDebugStringConvertible {
            var debugDescription: String { "<global-function Array>" }
            
            func call(interpret: Interpreter, args: [Any?]) -> Any? {
                if let size = args.first as? Double {
                    return ArrayWrapper(size: Int(size))
                }
                
                return ArrayWrapper(size: 0)
            }
        }
        
        class ReadLineCallable: Callable, CustomDebugStringConvertible {
            var debugDescription: String { "<global-function read>" }
            
            func call(interpret: Interpreter, args: [Any?]) -> Any? {
                return readLine()
            }
        }
        
        class PrintLineCallable: Callable, CustomDebugStringConvertible {
            var debugDescription: String { "<global-function read>" }
            
            func call(interpret: Interpreter, args: [Any?]) -> Any? {
                if let toPrint = args.first, toPrint != nil {
                    let prettyPrint = String(describing: toPrint!).replacingOccurrences(of: "\\n", with: "\n")
                    print(prettyPrint)
                } else {
                    print("\n")
                }
                
                return nil
            }
        }
        
        class IntCallable: Callable, CustomDebugStringConvertible {
            var debugDescription: String { "<global-function IntConvert>" }
            
            func call(interpret: Interpreter, args: [Any?]) -> Any? {
                if let toConvert = args.first as? String {
                    return Double(toConvert)
                }
                
                return Double(0.0)
            }
        }
        
        globalEnvironment.define(name: "clock", value: ClockCallable())
        globalEnvironment.define(name: "array", value: ArrayCallable())
        globalEnvironment.define(name: "readLine", value: ReadLineCallable())
        globalEnvironment.define(name: "printLine", value: PrintLineCallable())
        globalEnvironment.define(name: "Int", value: IntCallable())
        globalEnvironment.define(name: "NSObject", value: MyClass(name: "NSObject", superclass: nil))
        return globalEnvironment
    }
    
    public let globals = makeNativeFunctions()
    private var environment: Environment
    private var locals: [Expr: Int] = [:]
    public var printed: String = ""
    
    init() {
        self.environment = Environment(enclosing: self.globals)
    }
    
    public func display(_ stmts: [Stmt]) {
        print("=== Interpreter ===")
        print(self.getString(stmts))
    }
    
    public func getString(_ stmts: [Stmt]) -> String {
        self.interpret(stmts: stmts)
        let prettyPrint = self.printed.replacingOccurrences(of: "\\n", with: "\n")
        return prettyPrint
    }
    
    public func interpret(stmts: [Stmt]) {
        do {
            try stmts.forEach { try $0.accept(visitor: self) }
        } catch {
            self.printed += "\nERROR"
        }
    }
    
    // MARK: - Exprs
    func visitAssignExpr(_ expr: Expr.Assign) throws -> Any? {
        let value = try self.evaluate(expr.value)
        
        var newValue = value
        switch expr.oper.type {
        case .equals:                       break
        case .plusEquals, .plusPlus:        newValue = (self.environment.get(name: expr.name) as! Double) + (newValue as! Double)
        default:                            return nil
        }
        
        if let distance = self.locals[expr] {
            self.environment.assignAt(distance: distance, name: expr.name, value: newValue)
        } else {
            self.globals.assign(name: expr.name, value: newValue)
        }
        
        self.environment.assign(name: expr.name, value: newValue)
        return newValue
    }
    
    func visitBinaryExpr(_ expr: Expr.Binary) throws -> Any? {
        let left = try self.evaluate(expr.left)
        let right = try self.evaluate(expr.right)
        
        switch expr.oper.type {
        case .plus:             return self.plus(left, right)
        case .minus:            return (left as! Double) - (right as! Double)
        case .slash:            return (left as! Double) / (right as! Double)
        case .star:             return (left as! Double) * (right as! Double)
        case .percent:          return (left as! Double).truncatingRemainder(dividingBy: (right as! Double))
        case .less:             return (left as! Double) < (right as! Double)
        case .lessEqual:        return (left as! Double) <= (right as! Double)
        case .greater:          return (left as! Double) > (right as! Double)
        case .greaterEqual:     return (left as! Double) >= (right as! Double)
        case .equalsEquals:     return self.isEqual(left, right)
        case .bangEquals:       return !self.isEqual(left, right)
        default:                return nil
        }
    }
    
    func visitGroupingExpr(_ expr: Expr.Grouping) throws -> Any? {
        return try self.evaluate(expr.expr)
    }
    
    func visitLiteralExpr(_ expr: Expr.Literal) throws -> Any? {
        return expr.value
    }
    
    func visitArrayExpr(_ expr: Expr.Array) throws -> Any? {
        let values = try expr.contents.compactMap { try self.evaluate($0) }
        return ArrayWrapper(values: values)
    }
    
    func visitUnaryExpr(_ expr: Expr.Unary) throws -> Any? {
        let right = try self.evaluate(expr.right)
        
        switch expr.oper.type {
        case .minus:            return -(right as! Double)
        case .bang:             return !self.isTruthy(right)
        default:                return nil
        }
    }
    
    func visitVariableExpr(_ expr: Expr.Variable) throws -> Any? {
        return self.lookUpVariable(name: expr.name, expr: expr)
    }
    
    func visitLogicalExpr(_ expr: Expr.Logical) throws -> Any? {
        let oper = expr.oper
        let left = self.isTruthy(try self.evaluate(expr.left))
        
        if oper.type == .or, left { return true }
        
        let right = self.isTruthy(try self.evaluate(expr.right))
        
        switch oper.type {
        case .or:               return left || right
        case .and:              return left && right
        default: return nil
        }
    }
    
    func visitArrayGetExpr(_ expr: Expr.ArrayGet) throws -> Any? {
        let val = try self.evaluate(expr.object)
        if let array = val as? ArrayWrapper {
            let index = try self.evaluate(expr.index)
            let entry = array.get(index)
            return entry.value
        } else if let string = val as? String {
            if let index = try self.evaluate(expr.index) as? Double {
                let arr = Array(string)
                let entry = arr[Int(index)]
                return String(entry)
            }
        }
        
        return nil
    }
    
    func visitArraySetExpr(_ expr: Expr.ArraySet) throws -> Any? {
        if let array = try self.evaluate(expr.object) as? ArrayWrapper {
            let value = try self.evaluate(expr.value)
            let index = try self.evaluate(expr.index)
            array.set(index, to: value)
            return value
        }
        
        return nil
    }
    
    func visitGetExpr(_ expr: Expr.Get) throws -> Any? {
        let val = try self.evaluate(expr.object)
        
        if let object = val as? Instance {
            return object.get(expr.name.lex)
        } else if let klass = val as? MyClass {
            let fromSuperRef = (expr.object as? Expr.Supery) != nil
            let result = klass.findMethod(expr.name.lex, fromSuperRef: fromSuperRef)
            let method = result?.0
            if let instance = self.environment.get(name: "self") as? Instance, fromSuperRef {
                return method?.bind(instance, result?.1)
            }
            return method
        }
        
        return nil
    }
    
    func visitSetExpr(_ expr: Expr.Set) throws -> Any? {
        if let object = try self.evaluate(expr.object) as? Instance {
            let value = try self.evaluate(expr.value)
            
            var newValue = value
            switch expr.oper.type {
            case .equals:                   break
            case .plusEquals, .plusPlus:    newValue = (object.get(expr.name.lex) as! Double) + (newValue as! Double)
            default:                        break
            }
            
            object.set(expr.name.lex, value: newValue)
            return value
        }
        
        if let object = try self.evaluate(expr.object) as? ArrayEntry {
            let value = try self.evaluate(expr.value)
            object.set(value)
            return value
        }
        
        return nil
    }
    
    func visitSelfyExpr(_ expr: Expr.Selfy) throws -> Any? {
        return lookUpVariable(name: expr.keyword, expr: expr)
    }
    
    func visitSuperyExpr(_ expr: Expr.Supery) throws -> Any? {
        return lookUpVariable(name: expr.keyword, expr: expr)
    }
    
    func visitTernaryExpr(_ expr: Expr.Ternary) throws -> Any? {
        let condition = try self.evaluate(expr.condition)
        
        if self.isTruthy(condition) {
            return try self.evaluate(expr.thenExpr)
        } else {
            return try self.evaluate(expr.elseExpr)
        }
    }
    
    func visitCallExpr(_ expr: Expr.Call) throws -> Any? {
        let callee = try self.evaluate(expr.callee)
        let args = try expr.args.map { try self.evaluate($0) }
        let callable = callee as? Callable
        return callable?.call(interpret: self, args: args)
    }
    
    func visitMyTypeExpr(_ expr: Expr.MyType) throws -> Any? { nil }
    func visitBlockExprTypeExpr(_ expr: Expr.BlockExprType) throws -> Any? { nil }
    
    func visitBlockExprExpr(_ expr: Expr.BlockExpr) throws -> Any? {
        return MyBlock(declaration: expr, closure: self.environment)
    }
    
    @discardableResult
    private func evaluate(_ expr: Expr?) throws -> Any? {
        return try expr?.accept(visitor: self)
    }
    
    // MARK: - Stmts
    func visitBlockStmt(_ stmt: Stmt.Block) throws {
        let newEnv = Environment(enclosing: self.environment)
        try self.executeBlock(stmt, env: newEnv)
    }
    
    func visitExpressionStmt(_ stmt: Stmt.Expression) throws {
        try self.evaluate(stmt.expression)
    }
    
    func visitIfStmt(_ stmt: Stmt.If) throws {
        let condition = try self.evaluate(stmt.condition)
        
        if self.isTruthy(condition) {
            try self.execute(stmt.thenBranch)
        } else if let elseBranch = stmt.elseBranch {
            try self.execute(elseBranch)
        }
    }
    
    func visitVarStmt(_ stmt: Stmt.Var) throws {
        var value: Any? = nil
        if let initializer = stmt.initializer {
            value = try self.evaluate(initializer)
        }
        
        self.environment.define(name: stmt.name.lex, value: value)
    }
    
    func visitReturnStmt(_ stmt: Stmt.Return) throws {
        let returnValue = try self.evaluate(stmt.value)
        
        throw ControlFlow.functionReturn(returnValue)
    }
    
    func visitWhileStmt(_ stmt: Stmt.While) throws {
        while self.isTruthy(try self.evaluate(stmt.condition)) {
            try self.execute(stmt.body)
        }
    }
    
    func visitFunctionStmt(_ stmt: Stmt.Function) throws {
        let function = Function(declaration: stmt, closure: self.environment)
        self.environment.define(name: stmt.name.lex, value: function)
    }

    func visitForStmt(_ stmt: Stmt.For) throws {
        try self.execute(stmt.initializer)
        
        while self.isTruthy(try self.evaluate(stmt.condition)) {
            try self.execute(stmt.body)
            try self.evaluate(stmt.change)
        }
    }
    
    func visitClassDefStmt(_ stmt: Stmt.ClassDef) throws {
        let superclass = try self.evaluate(stmt.superclass)
        
        self.environment.define(name: stmt.name.lex, value: nil)
        
        var properties: [String : Any?] = [:]
        for property in stmt.properties {
            properties[property.name.lex] = self.initialValueForType(property.type.type)
        }
        
        let myClass = MyClass(name: stmt.name.lex, superclass: superclass as? MyClass, properties: properties)
        self.environment.assign(name: stmt.name, value: myClass)
    }
    
    func visitClassImplStmt(_ stmt: Stmt.ClassImpl) throws {
        var methods: [String : Function] = [:]
        for method in stmt.methods {
            let function = Function(declaration: method, closure: self.environment)
            methods[method.name.lex] = function
        }
        
        self.environment.implementClass(name: stmt.name, methods: methods)
    }
    
    func visitPrintStmt(_ stmt: Stmt.Print) throws {
        let value = try self.evaluate(stmt.value)
        if let unwrappedValue = value {
            self.printed += self.prettyify(String(describing: unwrappedValue))
        }
    }
    
    func visitTypeDefStmt(_ stmt: Stmt.TypeDef) throws {}
    
    private func execute(_ stmt: Stmt?) throws {
        try stmt?.accept(visitor: self)
    }
    
    // MARK: - Public Other
    public func resolve(expr: Expr, depth: Int) {
        self.locals[expr] = depth
    }
    
    public func executeStatements(_ stmts: [Stmt], env: Environment) throws {
        let temp = self.environment
        self.environment = env
        defer {
            self.environment = temp
        }
        
        for stmt in stmts {
            try self.execute(stmt)
        }
    }
    // MARK: - General Helpers
    private func lookUpVariable(name: Token, expr: Expr) -> Any? {
        if let distance = self.locals[expr] {
            return self.environment.getAt(distance: distance, name: name)
        } else {
            return self.globals.get(name: name)
        }
    }
    
    private func isTruthy(_ val: Any?) -> Bool {
        if val == nil { return false }
        if let val = val as? Bool { return val }
        return false
    }
    
    private func isEqual(_ a: Any?, _ b: Any?) -> Bool {
        if a == nil, b == nil { return true }
        if a == nil { return false }
        if b == nil { return false }
        if let a = a as? Double, let b = b as? Double { return a == b }
        if let a = a as? String, let b = b as? String { return a == b }
        return self.isTruthy(a) == self.isTruthy(b)
    }
    
    private func executeBlock(_ block: Stmt.Block, env: Environment) throws {
        try self.executeStatements(block.statements, env: env)
    }
    
    private func plus(_ left: Any?, _ right: Any?) -> Any? {
        let left = left ?? "nil"
        let right = right ?? "nil"
        
        switch (left, right) {
        case let (left as String, right as String): return left + right
        case let (left as Double, right as Double): return left + right
        case let (left as Double, right as String): return self.prettyify("\(left)") + right
        case let (left as String, right as Double): return left + self.prettyify("\(right)")
        default: return (left as! Double) + (right as! Double)
        }
    }
    
    private func prettyify(_ string: String) -> String {
        var string = string
        if string.hasSuffix(".0") { string.removeLast(2) }
        return string
    }
    
    private func initialValueForType(_ token: Token?) -> Any? {
        switch token?.type {
        case .number: 0.0
        case .string: ""
        case .classIdentifier: self.initialValueForBaseClasses(token!)
        default: nil
        }
    }
    
    private func initialValueForBaseClasses(_ token: Token) -> Any? {
        switch token.lex {
        case "NSString": ""
        case "NSInteger": 0.0
        default: nil
        }
    }
}
