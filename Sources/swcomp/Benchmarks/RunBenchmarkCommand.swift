// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

#if os(Linux)
    import CoreFoundation
#endif

import Foundation
import SwiftCLI

final class RunBenchmarkCommand: Command {

    let name = "run"
    let shortDescription = "Run the specified benchmark"
    let longDescription = "Runs the specified benchmark using external files.\nAvailable benchmarks: \(Benchmarks.allBenchmarks)"

    @Key("-i", "--iteration-count", description: "Sets the amount of the benchmark iterations")
    var iterationCount: Int?

    @Key("-s", "--save", description: "Saves results into the specified file")
    var savePath: String?

    @Flag("-a", "--append", description: "Appends results to a file instead of overwriting it when saving results")
    var append: Bool

    @Key("-c", "--compare", description: "Compares results with other results saved in the specified file")
    var comparePath: String?

    @Key("-d", "--description", description: "Adds a custom description when saving results")
    var description: String?

    @Flag("-t", "--preserve-timestamp", description: "Adds a timestamp when saving results")
    var preserveTimestamp: Bool

    @Flag("-W", "--no-warmup", description: "Disables warmup iteration")
    var noWarmup: Bool

    @Param var selectedBenchmark: Benchmarks
    @CollectedParam(minCount: 1) var inputs: [String]

    func execute() throws {
        guard self.iterationCount == nil || self.iterationCount! >= 1
            else { swcompExit(.benchmarkSmallIterCount) }

        var baseRuns = [SaveFile.Run]()
        if let comparePath = comparePath {
            let baseSaveFile = try SaveFile.load(from: comparePath)
            baseRuns = baseSaveFile.runs
        }
        self.printBaseMetadatas(runs: baseRuns)
        let baseResults = SaveFile.groupResults(runs: baseRuns)

        let title = "\(self.selectedBenchmark.titleName) Benchmark\n"
        print(String(repeating: "=", count: title.count))
        print(title)

        var newResults = [BenchmarkResult]()

        for input in self.inputs {
            print("Input: \(input)")
            let benchmark = self.selectedBenchmark.initialized(input)
            let iterationCount = self.iterationCount ?? benchmark.defaultIterationCount

            let warmup: Double?
            if !self.noWarmup {
                print("Warmup iteration...", terminator: " ")
                // Zeroth (excluded) iteration.
                warmup = benchmark.warmupIteration()
                print(benchmark.format(warmup!))
            } else {
                warmup = nil
            }

            var sum = 0.0
            var squareSum = 0.0

            print("Iterations: ", terminator: "")
            #if !os(Linux)
                fflush(__stdoutp)
            #endif
            var iterations = [Double]()
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
                iterations.append(speed)
            }

            let avg = sum / Double(iterationCount)
            let std = sqrt(squareSum / Double(iterationCount) - sum * sum / Double(iterationCount * iterationCount))
            let result = BenchmarkResult(name: self.selectedBenchmark.rawValue, input: input, iterCount: iterationCount,
                                         avg: avg, std: std, warmup: warmup, iters: iterations)

            if let baseResults = baseResults[result.id] {
                print("\nNEW:  average = \(benchmark.format(avg)), standard deviation = \(benchmark.format(std))")
                for (baseIndex, baseResult) in baseResults {
                    if let baseWarmup = baseResult.warmup {
                        print("BASE(\(baseIndex + 1)): average = \(benchmark.format(baseResult.avg)), standard deviation = \(benchmark.format(baseResult.std)), warmup = \(benchmark.format(baseWarmup))")
                    } else {
                        print("BASE(\(baseIndex + 1)): average = \(benchmark.format(baseResult.avg)), standard deviation = \(benchmark.format(baseResult.std))")
                    }
                    result.printComparison(with: baseResult)
                }
            } else {
                print("\nAverage = \(benchmark.format(avg)), standard deviation = \(benchmark.format(std))")
            }
            newResults.append(result)

            print()
        }

        if let savePath = self.savePath {
            let metadata = try BenchmarkMetadata(self.description, self.preserveTimestamp)
            var saveFile: SaveFile

            var isDir = ObjCBool(false)
            let saveFileExists = FileManager.default.fileExists(atPath: savePath, isDirectory: &isDir)

            if self.append && saveFileExists {
                if isDir.boolValue {
                    swcompExit(.benchmarkCannotAppendToDirectory)
                }
                saveFile = try SaveFile.load(from: savePath)
                if let foundRunIndex = saveFile.runs.firstIndex(where: { $0.metadata == metadata }) {
                    var foundRun = saveFile.runs[foundRunIndex]
                    foundRun.results.append(contentsOf: newResults)
                    foundRun.results.sort(by: { $0.id < $1.id })
                    saveFile.runs[foundRunIndex] = foundRun
                } else {
                    var uuid: UUID
                    repeat {
                        uuid = UUID()
                    } while saveFile.runs.contains(where: { $0.uuid == uuid })
                    saveFile.runs.append(SaveFile.Run(uuid: uuid, metadata: metadata, results: newResults.sorted(by: { $0.id < $1.id })))
                }
            } else {
                let uuid = UUID()
                saveFile = SaveFile(runs: [SaveFile.Run(uuid: uuid, metadata: metadata, results: newResults.sorted(by: { $0.id < $1.id }))])
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(saveFile)
            try data.write(to: URL(fileURLWithPath: savePath))
        }
    }

    private func printBaseMetadatas(runs: [SaveFile.Run]) {
        for (index, run) in runs.enumerated() {
            print("BASE(\(index + 1)) Metadata")
            print("---------------")
            run.metadata.print()
        }
    }

}
