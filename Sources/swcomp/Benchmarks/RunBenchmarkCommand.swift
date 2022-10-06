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

final class RunBenchmarkCommand: Command {

    let name = "run"
    let shortDescription = "Run the specified benchmark"
    let longDescription = "Runs the specified benchmark using external files.\nAvailable benchmarks: \(Benchmarks.allBenchmarks)"

    @Key("-i", "--iteration-count", description: "Sets the amount of the benchmark iterations")
    var iterationCount: Int?

    @Key("-s", "--save", description: "Saves the results into the specified file")
    var savePath: String?

    @Key("-c", "--compare", description: "Compares the results with other results saved in the specified file")
    var comparePath: String?

    @Flag("-W", "--no-warmup", description: "Disables warmup iteration")
    var noWarmup: Bool

    @Param var selectedBenchmark: Benchmarks
    @CollectedParam(minCount: 1) var inputs: [String]

    func execute() throws {
        guard self.iterationCount == nil || self.iterationCount! >= 1
            else { swcompExit(.benchmarkSmallIterCount) }

        let title = "\(self.selectedBenchmark.titleName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        var results = [BenchmarkResult]()
        var otherResults: [String : [BenchmarkResult]]? = nil
        if let comparePath = comparePath {
            otherResults = try SaveFile.loadResults(from: comparePath)
        }

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

            let avg = sum / Double(iterationCount)
            let std = sqrt(squareSum / Double(iterationCount) - sum * sum / Double(iterationCount * iterationCount))
            let result = BenchmarkResult(name: self.selectedBenchmark.rawValue, input: input, iterCount: iterationCount,
                                         avg: avg, std: std)

            if let otherResults = otherResults?[result.id] {
                if otherResults.count > 1 {
                    print("WARNING: There is more than one result with the same id=\(result.id) in the file \(self.comparePath!)")
                    print("Comparing with the first one...\n")
                }
                let other = otherResults.first!
                print("\nNEW:  average = \(benchmark.format(avg)), standard deviation = \(benchmark.format(std))")
                print("BASE: average = \(benchmark.format(other.avg)), standard deviation = \(benchmark.format(other.std))")
                result.printComparison(with: other)
            } else {
                print("\nAverage = \(benchmark.format(avg)), standard deviation = \(benchmark.format(std))")
            }
            results.append(result)

            print()
        }

        if let savePath = self.savePath {
            let saveFile = try SaveFile(nil, results)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(saveFile)
            try data.write(to: URL(fileURLWithPath: savePath))
        }
    }

}
