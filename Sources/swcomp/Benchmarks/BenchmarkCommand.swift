// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

#if os(Linux)
    import CoreFoundation
#endif

protocol BenchmarkCommand: Command {

    associatedtype InputType

    var inputs: CollectedParameter { get }

    var benchmarkName: String { get }

    func loadInput(_ input: String) throws -> InputType

    var benchmarkFunction: (InputType) throws -> Any { get }

}

extension BenchmarkCommand where InputType == Data {

    func loadInput(_ input: String) throws -> Data {
        let inputURL = URL(fileURLWithPath: input)
        return try Data(contentsOf: inputURL, options: .mappedIfSafe)
    }
            
}

extension BenchmarkCommand {

    func execute() throws {
        let title = "\(benchmarkName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        for input in self.inputs.value {
            print("Input: \(input)")

            let loadedInput = try self.loadInput(input)

            var totalTime: Double = 0

            var maxTime = Double(Int.min)
            var minTime = Double(Int.max)

            print("Iterations: ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            // Zeroth (excluded) iteration.
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try benchmarkFunction(loadedInput)
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print(String(format: "(%.3f) ", timeElapsed), terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            
            for _ in 1...10 {
                let startTime = CFAbsoluteTimeGetCurrent()
                _ = try benchmarkFunction(loadedInput)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print(String(format: "%.3f ", timeElapsed), terminator: "")
                #if !os(Linux)
                    fflush(__stdoutp)
                #endif
                totalTime += timeElapsed
                if timeElapsed > maxTime {
                    maxTime = timeElapsed
                }
                if timeElapsed < minTime {
                    minTime = timeElapsed
                }
            }
            print(String(format: "\nAverage: %.3f \u{B1} %.3f\n", totalTime / 10, (maxTime - minTime) / 2))
        }
    }

}
