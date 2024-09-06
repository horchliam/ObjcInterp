//
//  BaseTest.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/31/24.
//

import Foundation

class BaseTest {
    private var scanner = Scanner()
    private var parser = Parser()
    private let printer = ASTPrinter()
    private var interpreter = Interpreter()
    private var resolver: Resolver
    
    public var tests: [BaseTestCase] { [] }
    
    init() {
        self.resolver = Resolver(interpreter: self.interpreter)
    }
    
    internal func setUp() {
        self.scanner = Scanner()
        self.parser = Parser()
        self.interpreter = Interpreter()
        self.resolver = Resolver(interpreter: self.interpreter)
    }
    
    final public func executeTests() -> [TestResult] {
        var res: [TestResult] = []
        for test in tests {
            self.setUp()
            res += [TestResult(test: test, error: self.executeTest(test))]
        }
        
        return res
    }
    
    private func executeTest(_ test: BaseTestCase) -> String? {
        let shouldInterpret = !test.expectedResult.isEmpty
        let shouldCompareAST = !test.expectedAst.isEmpty
        let res = self.processSourceCode(test.sourceCode, shouldCompareAST: shouldCompareAST, shouldInterpret: shouldInterpret)
        
        var error: String? = nil
        if test.expectedAst != res.0 {
            error = "AST MISMATCH: \(test.expectedAst) != \(res.0)"
        }
        
        if test.expectedResult != res.1 {
            error = (error == nil ? "" : "\(error!) ") + "INTERPRETER MISALIGNMENT: \(test.expectedResult) != \(res.1)"
        }
        
        return error
    }
    
    private func processSourceCode(_ code: String, shouldCompareAST: Bool = false, shouldInterpret: Bool = false) -> (String, String) {
        let tokens = self.scanner.scanString(code)
        self.parser.setTokens(tokens)
        let ast = self.parser.parse()
        return (shouldCompareAST ? self.printer.getString(for: ast) : "", shouldInterpret ? self.interpret(stmts: ast) : "")
    }
    
    private func interpret(stmts: [Stmt]) -> String {
        self.resolver.resolve(stmts: stmts)
        return self.interpreter.getString(stmts)
    }
}

struct BaseTestCase {
    var sourceCode: String
    var expectedAst: String = ""
    var expectedResult: String = ""
    var name: String
}

struct TestResult {
    let test: BaseTestCase
    let error: String?
}
