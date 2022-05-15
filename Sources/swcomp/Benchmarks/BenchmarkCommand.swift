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

    @Key("-i", "--iteration-count", description: "Sets the amount of the benchmark iterations")
    var iterationCount: Int?

    @Flag("-W", "--no-warmup", description: "Disables warmup iteration")
    var noWarmup: Bool

    @Param var selectedBenchmark: Benchmarks
    @CollectedParam(minCount: 1) var inputs: [String]

    func execute() {
        guard self.iterationCount == nil || self.iterationCount! >= 1 else {
            print("ERROR: Iteration count, if set, must be not less than 1.")
            exit(1)
        }

        let title = "\(self.selectedBenchmark.titleName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        for input in self.inputs {
            print("Input: \(input)")
            let benchmark = self.selectedBenchmark.initialized(input)
            let iterationCount = self.iterationCount ?? benchmark.defaultIterationCount

            if !self.noWarmup {
                print("Warmup iteration...")
                // Zeroth (excluded) iteration.
                benchmark.warmupIteration()
            }

            var sum = 0.0
            var squareSum = 0.0

            print("Iterations: ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            for i in 1...iterationCount {
                if i > 1 {
                    print(", ", terminator: "")
                }
                let speed = benchmark.measure()
                print(benchmark.format(speed), terminator: "")
                #if !os(Linux)
                    fflush(__stdoutp)
                #endif
                sum += speed
                squareSum += speed * speed
            }

            let avgSpeed = sum / Double(iterationCount)
            print("\nAverage: " + benchmark.format(avgSpeed))
            let std = sqrt(squareSum / Double(iterationCount) - sum * sum / Double(iterationCount * iterationCount))
            print("Standard deviation: " + benchmark.format(std))

            print()
        }
    }

}
