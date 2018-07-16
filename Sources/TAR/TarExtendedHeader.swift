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
        // Split header data into entries with "\n" (0x0A) character as a separator.
        let entriesData = data.split(separator: 0x0A)

        var unknownRecords = [String: String]()

        for entryData in entriesData where !entryData.isEmpty {
            let entryDataSplit = entryData.split(separator: 0x20, maxSplits: 1, omittingEmptySubsequences: false)

            guard entryDataSplit.count == 2,
                let lengthString = String(data: entryDataSplit[0], encoding: .utf8),
                Int(lengthString) == entryData.count + 1
                else { throw TarError.wrongPaxHeaderEntry }

            // Split header entry into key-value pair with "=" (0x3D) character as a separator.
            let keyValueDataPair = entryDataSplit[1].split(separator: 0x3D, maxSplits: 1,
                                                            omittingEmptySubsequences: false)

            guard keyValueDataPair.count == 2,
                let key = String(data: keyValueDataPair[0], encoding: .utf8),
                let value = String(data: keyValueDataPair[1], encoding: .utf8)
                else { throw TarError.wrongPaxHeaderEntry}

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
                unknownRecords[key] = value
            }
        }

        self.unknownRecords = unknownRecords
    }

}
