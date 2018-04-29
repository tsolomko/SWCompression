// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct TarExtendedHeader {

    let unknownRecords: [String: String]

    var atime: Double?
    var ctime: Double?
    var mtime: Double?

    var size: Int?

    var uid: Int?
    var gid: Int?

    var uname: String?
    var gname: String?

    var path: String?
    var linkpath: String?

    var charset: String?
    var comment: String?

    init?(_ data: Data) throws {
        guard let headerString = String(data: data, encoding: .utf8)
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
            let key = String(keywordValueSplit[0])
            let value = String(keywordValueSplit[1])

            switch key {
            case "uid":
                self.uid = Int(value)
            case "gid":
                self.gid = Int(value)
            case "uname":
                self.uname = value
            case "gname":
                self.gname = value
            case "size":
                self.size = Int(value)
            case "atime":
                self.atime = Double(value)
            case "ctime":
                self.ctime = Double(value)
            case "mtime":
                self.mtime = Double(value)
            case "path":
                self.path = value
            case "linkpath":
                self.linkpath = value
            case "charset":
                self.charset = value
            case "comment":
                self.comment = value
            default:
                entries[key] = value
            }
        }

        self.unknownRecords = entries
    }

}
