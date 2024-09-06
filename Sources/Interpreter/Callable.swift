//
//  Callable.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 8/3/24.
//

protocol Callable {
    func call(interpret: Interpreter, args: [Any?]) -> Any?
}
