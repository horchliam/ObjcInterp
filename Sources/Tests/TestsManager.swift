//
//  TestsManager.swift
//  ObjcToSwift
//
//  Created by Liam Horch on 7/31/24.
//

import Foundation

class TestsManager {
    static func runTests() {
        let maxLength = self.tests.map { $0.tests.map { $0.name.count }.max() ?? 0 }.max() ?? 0
        
        for test in self.tests {
            let results = test.executeTests()
            for result in results {
                let padding = String(repeating: " ", count: maxLength + 5 - result.test.name.count)
                if let error = result.error {
                    print("\(result.test.name):\(padding)\(error)")
                } else {
                    print("\(result.test.name):\(padding)PASSED")
                }
            }
        }
        
        print("")
    }
    
    static var tests: [BaseTest] = [
        SimpleVariableTests(),
        GroupingTests(),
        ConditionalTests(),
        RandomBigTests(),
        LoopTests(),
        SimplePrintTests(),
        SimpleFunctionTests(),
        ResolverTests(),
        MathTests(),
        SimpleClassTests(),
        SimpleArrayTests(),
        AdvancedClassTests(),
        SimpleInheritanceTests(),
        LeetcodeTests(),
        SimpleBlockTests(),
        TypeDefTests()
    ]
}
