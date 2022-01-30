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

final class BenchmarkCommand: Command {

    let name = "benchmark"
    let shortDescription = "Perform the specified benchmark using external files, available benchmarks: \(Benchmarks.allBenchmarks)"

    @Key("-i", "--iteration-count", description: "Sets the amount of the benchmark iterations (default: 10)")
    var iterationCount: Int?

    @Flag("--no-warmup", description: "Disables warmup iteration")
    var noWarmup: Bool

    @Param var selectedBenchmark: Benchmarks
    @CollectedParam(minCount: 1) var inputs: [String]

    func execute() {
        guard self.iterationCount == nil || self.iterationCount! >= 1 else {
            print("ERROR: Iteration count, if set, must be not less than 1.")
            exit(1)
        }
        let iterationCount = self.iterationCount ?? 10

        let title = "\(self.selectedBenchmark.titleName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        let formatter = SpeedFormatter()

        for input in self.inputs {
            print("Input: \(input)")
            let benchmark = self.selectedBenchmark.initialized(input)

            if !self.noWarmup {
                print("Warmup iteration...")
                // Zeroth (excluded) iteration.
                benchmark.warmupIteration()
            }

            var totalSpeed = 0.0
            var maxSpeed = Double(Int.min)
            var minSpeed = Double(Int.max)

            print("Iterations: ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            for i in 1...iterationCount {
                if i > 1 {
                    print(", ", terminator: "")
                }
                let speed = benchmark.measure()
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
            }

            let avgSpeed = totalSpeed / Double(self.iterationCount ?? 10)
            let avgSpeedUnits = SpeedFormatter.Units(avgSpeed)
            let speedUncertainty = (maxSpeed - minSpeed) / 2
            var avgString = "\nAverage: "
            avgString += formatter.string(from: avgSpeed, units: avgSpeedUnits, hideUnits: true)
            avgString += " \u{B1} "
            avgString += formatter.string(from: speedUncertainty, units: avgSpeedUnits)
            print(avgString)

            // if calculateCompressionRatio {
            //     if warmupOutput == nil {
            //         print("WARNING: Unable to calculate compression ratio without a warmup iteration.")
            //     } else if let outputData = warmupOutput as? Data, outputData.count > 0 {
            //         let compressionRatio = Double(benchmarkInputSize!) / Double(outputData.count)
            //         print(String(format: "Compression ratio: %.3f", compressionRatio))
            //     } else {
            //         print("WARNING: Unable to calculate compression ratio.")
            //     }
            // }

            print()
        }
    }

}
