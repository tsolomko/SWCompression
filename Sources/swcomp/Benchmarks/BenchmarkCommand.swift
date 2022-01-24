// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

#if os(Linux)
    import CoreFoundation
#endif

import Foundation
import SWCompression
import SwiftCLI

protocol BenchmarkCommand: Command {

    associatedtype InputType
    associatedtype OutputType

    var iterationCount: Int? { get }
    var noWarmup: Bool { get }

    var inputs: [String] { get }

    var benchmarkName: String { get }

    var benchmarkInput: InputType? { get set }

    var benchmarkInputSize: Double? { get set }

    func benchmarkSetUp(_ input: String)

    func iterationSetUp()

    @discardableResult
    func benchmark() -> OutputType

    func iterationTearDown()

    func benchmarkTearDown()

    // Compression ratio is calculated only if the OutputType is Data, and the size of the output is greater than zero.
    var calculateCompressionRatio: Bool { get }

}

extension BenchmarkCommand {

    func benchmarkSetUp() { }

    func benchmarkTearDown() {
        benchmarkInput = nil
        benchmarkInputSize = nil
     }

    func iterationSetUp() { }

    func iterationTearDown() { }

}

extension BenchmarkCommand where InputType == Data {

    func benchmarkSetUp(_ input: String) {
        do {
            let inputURL = URL(fileURLWithPath: input)
            benchmarkInput = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            benchmarkInputSize = Double(benchmarkInput!.count)
        } catch let error {
            print("\nERROR: Unable to set up benchmark: input=\(input), error=\(error).")
            exit(1)
        }
    }

}

extension BenchmarkCommand {

    var calculateCompressionRatio: Bool {
        return false
    }

    func execute() {
        guard self.iterationCount == nil || self.iterationCount! >= 1 else {
            print("ERROR: Iteration count, if set, must be not less than 1.")
            exit(1)
        }
        let title = "\(benchmarkName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        let formatter = SpeedFormatter()

        for input in self.inputs {
            self.benchmarkSetUp(input)
            print("Input: \(input)")

            var totalSpeed = 0.0

            var maxSpeed = Double(Int.min)
            var minSpeed = Double(Int.max)

            print("Iterations: ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            var warmupOutput: OutputType? = nil
            if !self.noWarmup {
                // Zeroth (excluded) iteration.
                self.iterationSetUp()
                let startTime = CFAbsoluteTimeGetCurrent()
                warmupOutput = self.benchmark()
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                let speed = benchmarkInputSize! / timeElapsed
                print("(\(formatter.string(from: speed)))", terminator: "")
                #if !os(Linux)
                    fflush(__stdoutp)
                #endif
                self.iterationTearDown()
            }

            for i in 1...(self.iterationCount ?? 10) {
                if i > 1 || !noWarmup {
                    print(", ", terminator: "")
                }
                self.iterationSetUp()
                let startTime = CFAbsoluteTimeGetCurrent()
                self.benchmark()
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                let speed = benchmarkInputSize! / timeElapsed
                print(formatter.string(from: speed), terminator: "")
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
                self.iterationTearDown()
            }
            let avgSpeed = totalSpeed / Double(self.iterationCount ?? 10)
            let avgSpeedUnits = SpeedFormatter.Units(avgSpeed)
            let speedUncertainty = (maxSpeed - minSpeed) / 2
            var avgString = "\nAverage: "
            avgString += formatter.string(from: avgSpeed, units: avgSpeedUnits, hideUnits: true)
            avgString += " \u{B1} "
            avgString += formatter.string(from: speedUncertainty, units: avgSpeedUnits)
            print(avgString)

            if calculateCompressionRatio {
                if warmupOutput == nil {
                    print("WARNING: Unable to calculate compression ratio without a warmup iteration.")
                } else if let outputData = warmupOutput as? Data, outputData.count > 0 {
                    let compressionRatio = Double(benchmarkInputSize!) / Double(outputData.count)
                    print(String(format: "Compression ratio: %.3f", compressionRatio))
                } else {
                    print("WARNING: Unable to calculate compression ratio.")
                }
            }
            print()
            self.benchmarkTearDown()
        }
    }

}
