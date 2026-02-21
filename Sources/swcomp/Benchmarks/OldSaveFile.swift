// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct OldSaveFile: Codable {

    struct Run: Codable {

        var metadataUUID: UUID
        var results: [BenchmarkResult]

    }

    var metadatas: [UUID: BenchmarkMetadata]
    var runs: [Run]

    static func load(from path: String) throws -> OldSaveFile {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try decoder.decode(OldSaveFile.self, from: data)
    }

}
