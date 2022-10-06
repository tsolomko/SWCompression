// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

#if os(Linux)
    import CoreFoundation
#endif

import Foundation
import SwiftCLI

final class ShowBenchmarkCommand: Command {

    let name = "show"
    let shortDescription = "Print saved benchmarks results"

    @Key("-c", "--compare", description: "Compare with other saved benchmarks results")
    var comparePath: String?

    @Param var path: String

    func execute() throws {
        let newSaveFile = try SaveFile.load(from: self.path)
        print("NEW Metadata")
        print("------------")
        newSaveFile.printMetadata()
        let newResults = newSaveFile.groupedResults
        var baseResults: [String: [BenchmarkResult]]? = nil
        if let comparePath = comparePath {
            let baseSaveFile = try SaveFile.load(from: comparePath)
            print("BASE Metadata")
            print("-------------")
            baseSaveFile.printMetadata()
            baseResults = baseSaveFile.groupedResults
        }

        for resultId in newResults.keys.sorted() {
            let results = newResults[resultId]!
            if results.count > 1 {
                print("WARNING: There is more than one result with the same id=\(resultId) in the file \(self.path)")
                print("Skipped...\n")
                continue
            }

            let result = results.first!
            let benchmark = Benchmarks(rawValue: result.name)?.initialized(result.input)

            print("\(result.name) => \(result.input), iterations = \(result.iterCount)")

            if let baseResults = baseResults?[resultId] {
                if baseResults.count > 1 {
                    print("WARNING: There is more than one result with the same id=\(resultId) in the file \(self.comparePath!)")
                    print("Comparing with the first one...\n")
                }
                let other = baseResults.first!
                print("NEW:  average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std))")
                print("BASE: average = \(benchmark.format(other.avg)), standard deviation = \(benchmark.format(other.std))")
                result.printComparison(with: other)
            } else {
                print("Average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std))")
            }

            print()
        }
    }

}

fileprivate extension Optional where Wrapped == Benchmark {

    func format(_ value: Double) -> String {
        switch self {
        case .some(let benchmark):
            return benchmark.format(value)
        case .none:
            return String(value)
        }
    }

}
