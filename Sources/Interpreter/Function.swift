//
//  Function.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/4/24.
//

class Function: Callable, CustomDebugStringConvertible {
    var debugDescription: String { return "<function \(declaration.name.lex)>" }
    let isStatic: Bool
    
    private final let declaration: Stmt.Function
    private final let closure: Environment
    
    init(declaration: Stmt.Function, closure: Environment) {
        self.declaration = declaration
        self.closure = closure
        self.isStatic = declaration.isStatic
    }
    
    public func call(interpret: Interpreter, args: [Any?]) -> Any? {
        let newEnv = Environment(enclosing: self.closure)
        for (i, param) in declaration.params.enumerated() {
            newEnv.define(name: param.1.lex, value: args[i])
        }
        
        var returnValue: Any? = nil
        do {
            try interpret.executeStatements(self.declaration.body, env: newEnv)
        } catch ControlFlow.functionReturn(let value) {
            returnValue = value
        } catch {}
        
        return returnValue
    }
    
    public func bind(_ instance: Instance, _ superclass: MyClass? = nil) -> Function {
        let newEnv = Environment(enclosing: self.closure)
        newEnv.define(name: "self", value: instance)
        if let superclass = superclass {
            newEnv.define(name: "super", value: superclass)
        }
        
        for method in instance.methods {
            newEnv.define(name: method.key, value: instance.findMethod(method.key))
        }
        
        for property in instance.properties {
            newEnv.define(name: property.key, value: property.value)
        }
        
        return Function(declaration: self.declaration, closure: newEnv)
    }
}

class SimpleFunction: Function {
    private let closure: () -> Any?
    
    init(closure: @escaping () -> Any?) {
        self.closure = closure
        super.init(declaration: Stmt.Function(name: Token(type: .null), params: [], body: [], isStatic: true), closure: Environment())
    }
    
    override public func call(interpret: Interpreter, args: [Any?]) -> Any? {
        return self.closure()
    }
}
