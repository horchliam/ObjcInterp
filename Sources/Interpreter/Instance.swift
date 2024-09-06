//
//  Instance.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/6/24.
//

import Foundation

class Instance: CustomDebugStringConvertible {
    var debugDescription: String { self.klass.name + " instance" }
    internal let klass: MyClass
    internal var properties: [String : Any?]
    internal var methods: [String : Function]
    
    init(klass: MyClass) {
        self.klass = klass
        self.properties = klass.properties
        self.methods = klass.methods
        self.methods["init"] = SimpleFunction(closure: { return self })
    }
    
    public func get(_ name: String) -> Any? {
        if let val = self.properties[name] {
            return val
        }
        
        if let result = self.klass.findMethod(name, fromInstance: true) {
            let method = result.0
            let superclass = result.1
            return method.bind(self, superclass)
        } else if let method = self.methods[name] {
            return method
        }
        
        return nil
    }
    
    public func set(_ name: String, value: Any?) {
        self.properties[name] = value
    }
    
    public func findMethod(_ name: String) -> Function? {
        if let result = self.klass.findMethod(name, fromInstance: true) {
            return result.0
        } else if let method = self.methods[name] {
            return method
        }
        
        return nil
    }
}
