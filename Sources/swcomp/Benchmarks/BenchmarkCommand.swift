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

    func loadInput(_ input: String) throws -> (InputType, Double)

    var benchmarkFunction: (InputType) throws -> Any { get }

}

extension BenchmarkCommand where InputType == Data {

    func loadInput(_ input: String) throws -> (Data, Double) {
        let inputURL = URL(fileURLWithPath: input)
        let inputData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
        let attr = try FileManager.default.attributesOfItem(atPath: input)
        let inputSize = Double(attr[.size] as! UInt64)
        return (inputData, inputSize)
    }
            
}

extension BenchmarkCommand {

    func execute() throws {
        let title = "\(benchmarkName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        for input in self.inputs.value {
            print("Input: \(input)")

            let (loadedInput, inputSize) = try self.loadInput(input)

            var totalSpeed: Double = 0

            var maxSpeed = Double(Int.min)
            var minSpeed = Double(Int.max)

            print("Iterations: ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            // Zeroth (excluded) iteration.
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try benchmarkFunction(loadedInput)
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            let speed = inputSize / timeElapsed
            print("(\(SpeedFormat(speed).format())), ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            
            for _ in 1...10 {
                let startTime = CFAbsoluteTimeGetCurrent()
                _ = try benchmarkFunction(loadedInput)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                let speed = inputSize / timeElapsed
                print(SpeedFormat(speed).format() + ", ", terminator: "")
                #if !os(Linux)
                    fflush(__stdoutp)
                #endif
                totalSpeed += speed
                if speed > maxSpeed {
                    maxSpeed = speed
                }
                if speed < minSpeed {
                    minSpeed = speed
                }
            }
            let avgSpeed = totalSpeed / 10
            let devSpeed = (maxSpeed - minSpeed) / 2
            print("\nAverage: \(SpeedFormat(avgSpeed).format()) \u{B1} \(SpeedFormat(devSpeed).format())\n")
        }
    }

}
