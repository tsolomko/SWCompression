// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct TarExtendedHeader {

    var unknownRecords = [String: String]()

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

    init() {}

    init(_ data: Data) throws {
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

    func generateContainerData() throws -> Data {
        var headerString = ""
        if let atime = self.atime {
            headerString += try TarExtendedHeader.generateHeaderString("atime", String(atime))
        }

        if let ctime = self.ctime {
            headerString += try TarExtendedHeader.generateHeaderString("ctime", String(ctime))
        }

        if let mtime = self.mtime {
            headerString += try TarExtendedHeader.generateHeaderString("mtime", String(mtime))
        }

        if let size = self.size {
            headerString += try TarExtendedHeader.generateHeaderString("size", String(size))
        }

        if let uid = self.uid {
            headerString += try TarExtendedHeader.generateHeaderString("uid", String(uid))
        }

        if let gid = self.gid {
            headerString += try TarExtendedHeader.generateHeaderString("gid", String(gid))
        }

        if let uname = self.uname {
            headerString += try TarExtendedHeader.generateHeaderString("uname", uname)
        }

        if let gname = self.gname {
            headerString += try TarExtendedHeader.generateHeaderString("gname", gname)
        }

        if let path = self.path {
            headerString += try TarExtendedHeader.generateHeaderString("path", path)
        }

        if let linkpath = self.linkpath {
            headerString += try TarExtendedHeader.generateHeaderString("linkpath", linkpath)
        }

        if let charset = self.charset {
            headerString += try TarExtendedHeader.generateHeaderString("charset", charset)
        }

        if let comment = self.comment {
            headerString += try TarExtendedHeader.generateHeaderString("comment", comment)
        }

        for (key, value) in self.unknownRecords {
            headerString += try TarExtendedHeader.generateHeaderString(key, value)
        }

        return headerString.data(using: .utf8)!
    }

    private static func generateHeaderString(_ fieldName: String, _ valueString: String) throws -> String {
        guard let valueCount = valueString.data(using: .utf8)?.count
            else { throw TarCreateError.utf8NonEncodable }
        return TarExtendedHeader.calculateCountString(fieldName, valueCount) + " \(fieldName)=\(valueString)\n"
    }

    private static func calculateCountString(_ fieldName: String, _ valueCount: Int) -> String {
        let fixedCount = 3 + fieldName.count + valueCount // 3 = Space + "=" + "\n"
        var countStr = String(fixedCount)
        // Workaround for cases when number of figures in count increases when the count itself is included.
        while true {
            let totalCount = fixedCount + countStr.count
            if String(totalCount).count > countStr.count {
                countStr = String(totalCount)
                continue
            } else {
                countStr = String(totalCount)
                break
            }
        }
        return countStr
    }

}
