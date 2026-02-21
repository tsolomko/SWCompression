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

    init(_ oldSaveFile: OldSaveFile) {
        var d = [UUID: [BenchmarkResult]]()
        for run in oldSaveFile.runs {
            d[run.metadataUUID] = (d[run.metadataUUID] ?? [BenchmarkResult]()) + run.results
        }

        self.runs = [Run]()
        for (uuid, results) in d {
            guard let metadata = oldSaveFile.metadatas[uuid]
                else { swcompExit(.benchmarkOldFormatNoUUIDMetadata(uuid)) }
            self.runs.append(Run(uuid: uuid, metadata: metadata, results: results.sorted(by: { $0.id < $1.id })))
        }
    }

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
        } else if generalDict["metadatas"] != nil && generalDict["runs"] != nil {
            let decoder = JSONDecoder()
            let oldSaveFile = try decoder.decode(OldSaveFile.self, from: data)
            print("WARNING: Old save file format detected. Its support will be removed in the future. Use \'benchmark convert' to upgrade.")
            return SaveFile(oldSaveFile)
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
