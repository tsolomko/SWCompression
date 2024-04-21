// Copyright (c) 2024 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Also known as PAX header.
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

    init(_ data: Data) throws {
        var unknownRecords = [String: String]()
        var i = data.startIndex
        while i < data.endIndex {
            let lengthStartIndex = i
            while data[i] != 0x20 {
                i += 1
            }
            guard let lengthString = String(data: data[lengthStartIndex..<i], encoding: .utf8),
                  let length = Int(lengthString)
                else { throw TarError.wrongPaxHeaderEntry }

            i += 1
            let keyStartIndex = i
            while data[i] != 0x3D {
                i += 1
            }
            guard let key = String(data: data[keyStartIndex..<i], encoding: .utf8)
                else { throw TarError.wrongPaxHeaderEntry }

            i += 1
            var valueBytes = [UInt8]()
            // Length includes the trailing newline character.
            while i - lengthStartIndex + 1 < length {
                valueBytes.append(data[i])
                i += 1
            }

            // Check and skip trailing newline character.
            guard data[i] == 0x0A
                else { throw TarError.wrongPaxHeaderEntry }
            i += 1

            guard let value = String(data: Data(valueBytes), encoding: .utf8)
                else { continue }

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
        // The PAX header must end with a newline character since it's the end marker of the last (and all) record.
        guard data.last == 0x0A || data.isEmpty
            else { throw TarError.wrongPaxHeaderEntry }

        self.unknownRecords = unknownRecords
    }

    init(_ info: TarEntryInfo) {
        let maxOctalLengthEight = (1 << 24) - 1
        let maxOctalLengthTwelve = (1 << 36) - 1

        if let uid = info.ownerID, uid > maxOctalLengthEight {
            self.uid = uid
        }
        if let gid = info.groupID, gid > maxOctalLengthEight {
            self.gid = gid
        }
        if let uname = info.ownerUserName {
            let asciiUnameData = uname.data(using: .ascii)
            if asciiUnameData == nil || asciiUnameData!.count > 32 {
                self.uname = uname
            }
        }
        if let gname = info.ownerGroupName {
            let asciiGnameData = gname.data(using: .ascii)
            if asciiGnameData == nil || asciiGnameData!.count > 32 {
                self.gname = gname
            }
        }
        if let size = info.size, size > maxOctalLengthTwelve {
            self.size = size
        }
        if let mtime = info.modificationTime?.timeIntervalSince1970,
            (mtime < 0 || mtime > Double(maxOctalLengthTwelve)) {
            self.mtime = mtime
        }
        // The non-asciiness of the (link)name is still a reason to use PAX headers, even though we encode using UTF-8
        // in basic TAR headers anyway, because one can imagine a third-party implementation, that can read PAX headers
        // properly, but still expects all string fields in the basic header to be ASCII-only. By using PAX headers we
        // can "support" those implementations, though this will work only if they skip (non-ASCII/invalid) string
        // fields after encountering a PAX header.
        let asciiNameData = info.name.data(using: .ascii)
        if asciiNameData == nil || asciiNameData!.count > 100 {
            self.path = info.name
        }
        let asciiLinkNameData = info.name.data(using: .ascii)
        if asciiLinkNameData == nil || asciiLinkNameData!.count > 100 {
            self.linkpath = info.linkName
        }

        self.atime = info.accessTime?.timeIntervalSince1970
        self.ctime = info.creationTime?.timeIntervalSince1970
        self.charset = info.charset
        self.comment = info.comment
        self.unknownRecords = info.unknownExtendedHeaderRecords ?? [:]
    }

    func generateContainerData() -> Data {
        var headerString = ""
        if let atime = self.atime {
            headerString += TarExtendedHeader.generateHeaderString("atime", String(atime))
        }

        if let ctime = self.ctime {
            headerString += TarExtendedHeader.generateHeaderString("ctime", String(ctime))
        }

        if let mtime = self.mtime {
            headerString += TarExtendedHeader.generateHeaderString("mtime", String(mtime))
        }

        if let size = self.size {
            headerString += TarExtendedHeader.generateHeaderString("size", String(size))
        }

        if let uid = self.uid {
            headerString += TarExtendedHeader.generateHeaderString("uid", String(uid))
        }

        if let gid = self.gid {
            headerString += TarExtendedHeader.generateHeaderString("gid", String(gid))
        }

        if let uname = self.uname {
            headerString += TarExtendedHeader.generateHeaderString("uname", uname)
        }

        if let gname = self.gname {
            headerString += TarExtendedHeader.generateHeaderString("gname", gname)
        }

        if let path = self.path {
            headerString += TarExtendedHeader.generateHeaderString("path", path)
        }

        if let linkpath = self.linkpath {
            headerString += TarExtendedHeader.generateHeaderString("linkpath", linkpath)
        }

        if let charset = self.charset {
            headerString += TarExtendedHeader.generateHeaderString("charset", charset)
        }

        if let comment = self.comment {
            headerString += TarExtendedHeader.generateHeaderString("comment", comment)
        }

        for (key, value) in self.unknownRecords {
            headerString += TarExtendedHeader.generateHeaderString(key, value)
        }

        return Data(headerString.utf8)
    }

    private static func generateHeaderString(_ fieldName: String, _ valueString: String) -> String {
        let valueCount = Data(valueString.utf8).count
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
