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

    @Key("-s", "--save", description: "Saves the results into the specified file")
    var savePath: String?

    @Key("-c", "--compare", description: "Compares the results with the results saved in the specified file")
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
        var otherResults: [BenchmarkResult]? = nil
        if let comparePath = comparePath {
            let data = try Data(contentsOf: URL(fileURLWithPath: comparePath))
            let decoder = JSONDecoder()
            otherResults = try decoder.decode(Array<BenchmarkResult>.self, from: data)
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

            let avgSpeed = sum / Double(iterationCount)
            print("\nAverage: " + benchmark.format(avgSpeed))
            let std = sqrt(squareSum / Double(iterationCount) - sum * sum / Double(iterationCount * iterationCount))
            print("Standard deviation: " + benchmark.format(std))

            let result = BenchmarkResult(name: self.selectedBenchmark.rawValue, input: input, iterCount: iterationCount,
                                         avg: avgSpeed, std: std)
            if let other = otherResults?.first(where: { $0.name == result.name && $0.input == result.input }) {
                let comparison = result.compare(with: other)
                let diff = (result.avg / other.avg - 1) * 100
                if diff < 0 {
                    switch comparison {
                    case 1:
                        print(String(format: "OK  %f%% (p-value > 0.05)", diff))
                    case nil:
                        print("Cannot compare due to unsupported iteration count.")
                    case -1:
                        print(String(format: "REG %f%% (p-value < 0.05)", diff))
                    case 0:
                        print(String(format: "REG %f%% (p-value = 0.05)", diff))
                    default:
                        swcompExit(.benchmarkUnknownCompResult)
                    }
                }
                else if diff > 0 {
                    switch comparison {
                    case 1:
                        print(String(format: "OK  %f%% (p-value > 0.05)", diff))
                    case nil:
                        print("Cannot compare due to unsupported iteration count.")
                    case -1:
                        print(String(format: "IMP %f%% (p-value < 0.05)", diff))
                    case 0:
                        print(String(format: "IMP %f%% (p-value = 0.05)", diff))
                    default:
                        swcompExit(.benchmarkUnknownCompResult)
                    }
                } else {
                    print("OK (exact match of averages)")
                }
            }
            results.append(result)

            print()
        }

        if let savePath = self.savePath {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(results)
            try data.write(to: URL(fileURLWithPath: savePath))
        }
    }

}
