//
//  ArrayWrapper.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/8/24.
//

class ArrayWrapper: Instance {
    var contents: [ArrayEntry]
    
    init(size: Int) {
        self.contents = []
        for _ in 0..<size {
            self.contents += [ArrayEntry()]
        }
        super.init(klass: MyClass(name: "Array",
                                  superclass: nil))
        let methods = ["pop": SimpleFunction(closure: { self.contents.removeLast() }),
                       "count": SimpleFunction(closure: { return Double(self.contents.count) })]
        self.methods = methods
    }
    
    init(values: [Any]) {
        self.contents = []
        for value in values {
            self.contents += [ArrayEntry(value: value)]
        }
        
        super.init(klass: MyClass(name: "Array",
                                  superclass: nil))
        let methods = ["pop": SimpleFunction(closure: { self.contents.removeLast() }),
                       "count": SimpleFunction(closure: { return Double(self.contents.count) })]
        self.methods = methods
    }
    
    public func get(_ i: Any?) -> ArrayEntry {
        if let i = i as? Double {
            return self.contents[Int(i)]
        }
        
        print(i)
        
        return .init()
    }
    
    public func set(_ i: Any?, to val: Any?) {
        if let i = i as? Double {
            self.contents[Int(i)].set(val)
        }
    }
}

class ArrayEntry: CustomDebugStringConvertible {
    var debugDescription: String {
        if let value = self.value as? String {
            return value
        } else if let value = value as? Double {
            return String(describing: value)
        } else {
            return "nil"
        }
    }
    var value: Any?
    
    init(value: Any? = nil) {
        self.value = value
    }
    
    public func set(_ value: Any?) {
        self.value = value
    }
}
