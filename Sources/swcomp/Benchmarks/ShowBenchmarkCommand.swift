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
        let loadedResults = try SaveFile.loadResults(from: self.path)
        var otherResults: [String : [BenchmarkResult]]? = nil
        if let comparePath = comparePath {
            otherResults = try SaveFile.loadResults(from: comparePath)
        }

        for resultId in loadedResults.keys.sorted() {
            let results = loadedResults[resultId]!
            if results.count > 1 {
                print("WARNING: There is more than one result with the same id=\(resultId) in the file \(self.path)")
                print("Skipped...\n")
                continue
            }

            let result = results.first!
            let benchmark = Benchmarks(rawValue: result.name)?.initialized(result.input)

            print("\(result.name) => \(result.input), iterations = \(result.iterCount)")

            if let otherResults = otherResults?[resultId] {
                if otherResults.count > 1 {
                    print("WARNING: There is more than one result with the same id=\(resultId) in the file \(self.comparePath!)")
                    print("Comparing with the first one...\n")
                }
                let other = otherResults.first!
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
