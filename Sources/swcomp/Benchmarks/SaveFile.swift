// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SaveFile: Codable {

    struct Run: Codable {

        var uuid: UUID
        var metadata: BenchmarkMetadata
        var results: [BenchmarkResult]

    }

    var formatVersion = 2
    var runs: [Run]

    init(runs: [SaveFile.Run]) {
        self.runs = runs
    }

    static func load(from path: String) throws -> SaveFile {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let generalDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { swcompExit(.benchmarkUnrecognizedSaveFile) }
        if let formatVersion = generalDict["formatVersion"] {
            guard let intFormatVersion = formatVersion as? Int
                else { swcompExit(.benchmarkUnrecognizedFormatVersion) }
            guard intFormatVersion == 2
                else { swcompExit(.benchmarkUnsupportedFormatVersion(intFormatVersion)) }
            let decoder = JSONDecoder()
            return try decoder.decode(SaveFile.self, from: data)
        } else {
            swcompExit(.benchmarkUnrecognizedSaveFile)
        }
    }

    static func groupResults(runs: [SaveFile.Run]) -> [String: [(Int, BenchmarkResult)]] {
        var groupedResults = [String: [(Int, BenchmarkResult)]]()
        for (index, run) in runs.enumerated() {
            for result in run.results {
                let resultId = result.id
                groupedResults[resultId] = (groupedResults[resultId] ?? Array()) + [(index, result)]
            }
        }
        return groupedResults
    }

}
