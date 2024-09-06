//
//  MyBlock.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/23/24.
//

class MyBlock: Callable, CustomDebugStringConvertible {
    var debugDescription: String { return "<block>" }
    
    private final let declaration: Expr.BlockExpr
    private final let closure: Environment
    
    init(declaration: Expr.BlockExpr, closure: Environment) {
        self.declaration = declaration
        self.closure = closure.copy()
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
}
