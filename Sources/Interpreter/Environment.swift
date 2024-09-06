//
//  Environment.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/2/24.
//

class Environment {
    private final var enclosing: Environment?
    private final var values: [String : Any?]
    
    init(enclosing: Environment? = nil, 
         values: [String : Any?] = [:]) {
        self.enclosing = enclosing
        self.values = values
    }
    
    public func copy() -> Environment {
        return .init(enclosing: self.enclosing, values: self.values)
    }
    
    public func printEnv() {
        var res = ""
        var cur: Environment? = self
        
        while cur != nil {
            res += "{"
            cur?.values.forEach { res += " \($0.key): \($0.value ?? "nil"),"}
            res += "} -> "
            cur = cur?.enclosing
        }
        
        print(res)
    }
    
    public func define(name: String, value: Any?) {
        values[name] = value
    }
    
    public func getAt(distance: Int, name: Token) -> Any? {
        return self.ancestor(distance: distance)?.get(name: name)
    }
    
    private func ancestor(distance: Int) -> Environment? {
        var res: Environment? = self
        var i = 0
        
        while i < distance {
            res = res?.enclosing
            i += 1
        }
        
        return res
    }
    
    public func get(name: Token) -> Any? {
        if let value = values[name.lex] {
            return value
        }
        
        if let enclosing = self.enclosing { return enclosing.get(name: name) }
        
        return nil
    }
    
    public func get(name: String) -> Any? {
        if let value = values[name] {
            return value
        }
        
        if let enclosing = self.enclosing { return enclosing.get(name: name) }
        
        return nil
    }
    
    public func assignAt(distance: Int, name: Token, value: Any?) {
        self.ancestor(distance: distance)?.define(name: name.lex, value: value)
    }
    
    public func assign(name: Token, value: Any?) {
        if let _ = values[name.lex] {
            self.define(name: name.lex, value: value)
            return
        }
        
        if let enclosing = self.enclosing { enclosing.assign(name: name, value: value) }
    }
    
    public func implementClass(name: Token, methods: [String : Function]) {
        if let klass = self.values[name.lex] as? MyClass {
            methods.forEach { entry in
                klass.methods[entry.key] = entry.value
            }
        }
    }
}
