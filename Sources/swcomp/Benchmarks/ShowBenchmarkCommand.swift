// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SwiftCLI

final class ShowBenchmarkCommand: Command {

    let name = "show"
    let shortDescription = "Print saved benchmarks results"

    @Key("-c", "--compare", description: "Compare with other saved benchmarks results")
    var comparePath: String?

    @Key("--self-compare", description: "Compare runs within the same file with new results identified by run UUID")
    var selfCompare: String?

    @Flag("--print-uuid", description: "Prints internal UUIDs of saved benchmark runs")
    var printUuid: Bool

    @Flag("--metadata-only", description: "Prints only metadata of saved benchmark runs")
    var metadataOnly: Bool

    @Param var path: String

    var optionGroups: [OptionGroup] {
        return [.atMostOne($comparePath, $selfCompare)]
    }

    func execute() throws {
        let newSaveFile = try SaveFile.load(from: self.path)
        var newRuns: [SaveFile.Run]
        if let newUUIDString = self.selfCompare {
            guard let newUUID = UUID(uuidString: newUUIDString)
                else { swcompExit(.benchmarkBadUUID) }
            guard let newRun = newSaveFile.runs.first(where: { $0.uuid == newUUID} )
                else { swcompExit(.benchmarkNoUUID) }
            newRuns = [newRun]
        } else {
            newRuns = newSaveFile.runs
        }
        self.printMetadatas(runs: newRuns, name: "NEW")

        var baseRuns = [SaveFile.Run]()
        if let comparePath = comparePath {
            let baseSaveFile = try SaveFile.load(from: comparePath)
            baseRuns = baseSaveFile.runs
        } else if let newUUIDString = self.selfCompare {
            // No need to double-check validity of input UUID. It was done already when loading the "new" run.
            let newUUID = UUID(uuidString: newUUIDString)!
            baseRuns = newSaveFile.runs.filter({ $0.uuid != newUUID })
        }
        self.printMetadatas(runs: baseRuns, name: "BASE")

        guard !self.metadataOnly
            else { return }

        // There might be results for the same benchmark-input-iterCount tuple in different runs. We want to print those
        // results together, so we have to group them based on their `id`.
        let newResults = SaveFile.groupResults(runs: newRuns)
        let baseResults = SaveFile.groupResults(runs: baseRuns)

        // Even though we try to sort results before writing a save file, after grouping they can appear in `newResults`
        // in essentially arbitrary order.
        for id in newResults.keys.sorted() {
            let results = newResults[id]!
            print()
            print("----------------")
            print()
            print("\(results.first!.1.name) => \(results.first!.1.input), iterations = \(results.first!.1.iterCount)")
            print()
            for (index, result) in results {
                let benchmark = Benchmarks(rawValue: result.name)?.initialized(result.input)
                if let warmup = result.warmup {
                    print("NEW(\(index + 1)):  average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std)), warmup = \(benchmark.format(warmup))")
                } else {
                    print("NEW(\(index + 1)):  average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std))")
                }
                if let baseResults = baseResults[id] {
                    for (baseIndex, baseResult) in baseResults {
                        if let baseWarmup = baseResult.warmup {
                            print("BASE(\(baseIndex + 1)): average = \(benchmark.format(baseResult.avg)), standard deviation = \(benchmark.format(baseResult.std)), warmup = \(benchmark.format(baseWarmup))")
                        } else {
                            print("BASE(\(baseIndex + 1)): average = \(benchmark.format(baseResult.avg)), standard deviation = \(benchmark.format(baseResult.std))")
                        }
                        result.printComparison(with: baseResult)
                    }
                }
            }
        }
    }

    private func printMetadatas(runs: [SaveFile.Run], name: String) {
        for (index, run) in runs.enumerated() {
            print("\(name)(\(index + 1)) Metadata")
            print("---------------")
            if self.printUuid {
                print("UUID: \(run.uuid)")
            }
            run.metadata.print()
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
