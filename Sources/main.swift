import Foundation

if CommandLine.arguments.count >= 2 {
    let arg = CommandLine.arguments[1]
    if arg == "runTests" {
        TestsManager.runTests()
    } else {
        let curFile = URL(fileURLWithPath: #file)
        let desiredFile = curFile.deletingLastPathComponent().path + arg

        let scanner = Scanner()
        let tokens = scanner.scan(at: desiredFile)

        let parser = Parser()
        parser.setTokens(tokens)
        let ast = parser.parse()

        let interpreter = Interpreter()
        let resolver = Resolver(interpreter: interpreter)
        resolver.resolve(stmts: ast)
        interpreter.interpret(stmts: ast)
    }
} else {
    print("Please provide a file to interpret")
}
