// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct TarExtendedHeader {

    let entries: [String: String]

    init?(_ data: Data?) throws {
        guard let data = data, let headerString = String(data: data, encoding: .utf8)
            else { return nil }

        var entries = [String: String]()

        let headerEntries = headerString.components(separatedBy: "\n")
        for headerEntry in headerEntries {
            guard !headerEntry.isEmpty
                else { continue }
            let headerEntrySplit = headerEntry.split(separator: " ", maxSplits: 1,
                                                     omittingEmptySubsequences: false)
            guard Int(headerEntrySplit[0]) == headerEntry.count + 1
                else { throw TarError.wrongPaxHeaderEntry }
            let keywordValue = headerEntrySplit[1]
            let keywordValueSplit = keywordValue.split(separator: "=", maxSplits: 1,
                                                       omittingEmptySubsequences: false)

            entries[String(keywordValueSplit[0])] = String(keywordValueSplit[1])
        }

        self.entries = entries
    }

}
