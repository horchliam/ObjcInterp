//
//  MyClass.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/6/24.
//

class MyClass: Callable, CustomDebugStringConvertible {
    final let name: String
    final let superclass: MyClass?
    var debugDescription: String { self.name }
    public var properties: [String : Any?]
    public var methods: [String : Function]
    
    init(name: String, superclass: MyClass?, properties: [String : Any?] = [:], methods: [String : Function] = [:]) {
        self.name = name
        self.superclass = superclass
        self.properties = properties
        self.methods = methods
        self.methods["alloc"] = SimpleFunction(closure: { return self.allocate() })
    }
    
    func call(interpret: Interpreter, args: [Any?]) -> Any? {
        return self.allocate()
    }
    
    func allocate() -> Instance {
        let instance = Instance(klass: self)
        return instance
    }
    
    func findMethod(_ name: String, fromInstance: Bool = false, fromSuperRef: Bool = false) -> (Function, MyClass?)? {
        if let method = self.methods[name], method.isStatic || fromInstance || fromSuperRef {
            return (method, self.superclass)
        }
        
        if let superclass = self.superclass {
            return superclass.findMethod(name, fromInstance: fromInstance, fromSuperRef: fromSuperRef)
        }
        
        return nil
    }
}
