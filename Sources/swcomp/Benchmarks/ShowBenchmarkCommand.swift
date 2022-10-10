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
        var newMetadatas = Dictionary(uniqueKeysWithValues: zip(newSaveFile.metadatas.keys, (1...newSaveFile.metadatas.count).map { String($0) }))
        if newMetadatas.count == 1 {
            newMetadatas[newMetadatas.first!.key] = ""
        }
        for (metadataUUID, index) in newMetadatas.sorted(by: { $0.value < $1.value }) {
            print("NEW\(index) Metadata")
            print("---------------")
            newSaveFile.metadatas[metadataUUID]!.print()
        }

        var newResults = [String: [(BenchmarkResult, UUID)]]()
        for newRun in newSaveFile.runs {
            newResults.merge(Dictionary(grouping: newRun.results.map { ($0, newRun.metadataUUID) }, by: { $0.0.id }),
                                  uniquingKeysWith: { $0 + $1 })
        }

        var baseResults = [String: [(BenchmarkResult, UUID)]]()
        var baseMetadatas = [UUID: String]()
        if let comparePath = comparePath {
            let baseSaveFile = try SaveFile.load(from: comparePath)

            baseMetadatas = Dictionary(uniqueKeysWithValues: zip(baseSaveFile.metadatas.keys, (1...baseSaveFile.metadatas.count).map { String($0) }))
            if baseMetadatas.count == 1 {
                baseMetadatas[baseMetadatas.first!.key] = ""
            }
            // TODO: The order of printing is potentially non-stable between executions.
            for (metadataUUID, index) in baseMetadatas {
                print("BASE\(index) Metadata")
                print("----------------")
                baseSaveFile.metadatas[metadataUUID]!.print()
            }

            for baseRun in baseSaveFile.runs {
                baseResults.merge(Dictionary(grouping: baseRun.results.map { ($0, baseRun.metadataUUID) }, by: { $0.0.id }),
                                  uniquingKeysWith: { $0 + $1 })
            }
        }

        for resultId in newResults.keys.sorted() {
            let results = newResults[resultId]!
            for (result, metadataUUID) in results {
                let benchmark = Benchmarks(rawValue: result.name)?.initialized(result.input)

                print("\(result.name) => \(result.input), iterations = \(result.iterCount)")

                if let baseResults = baseResults[resultId] {
                    print("NEW\(newMetadatas[metadataUUID]!):  average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std))")
                    for (other, baseUUID) in baseResults {
                        print("BASE\(baseMetadatas[baseUUID]!): average = \(benchmark.format(other.avg)), standard deviation = \(benchmark.format(other.std))")
                        result.printComparison(with: other)
                    }
                } else {
                    print("Average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std))")
                }

                print()
            }
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
