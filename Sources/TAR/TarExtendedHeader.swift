// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct TarExtendedHeader {

    let atime: Date?
    let charset: String?
    let ctime: Date?
    let mtime: Date?
    let comment: String?
    let gid: Int?
    let gname: String?
    //    let hdrcharset: String? TODO:
    let linkpath: String?
    let path: String?
    let size: Int?
    let uid: Int?
    let uname: String?

    let unknownEntries: [String: String]

    init?(_ data: Data) throws {
        guard let headerString = String(data: data, encoding: .utf8)
            else { return nil }

        var atime: Date?
        var charset: String?
        var ctime: Date?
        var mtime: Date?
        var comment: String?
        var gid: Int?
        var gname: String?
        //    var hdrcharset: String? TODO:
        var linkpath: String?
        var path: String?
        var size: Int?
        var uid: Int?
        var uname: String?

        var unknownEntries = [String: String]()

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

            switch keywordValueSplit[0] {
            case "atime":
                if let interval = Double(keywordValueSplit[1]) {
                    atime = Date(timeIntervalSince1970: interval)
                }
            case "charset":
                charset = String(keywordValueSplit[1])
            case "ctime":
                if let interval = Double(keywordValueSplit[1]) {
                    ctime = Date(timeIntervalSince1970: interval)
                }
            case "mtime":
                if let interval = Double(keywordValueSplit[1]) {
                    mtime = Date(timeIntervalSince1970: interval)
                }
            case "comment":
                comment = String(keywordValueSplit[1])
            case "gid":
                gid = Int(keywordValueSplit[1])
            case "gname":
                gname = String(keywordValueSplit[1])
            case "hdrcharset":
                break // TODO:
            case "linkpath":
                linkpath = String(keywordValueSplit[1])
            case "path":
                path = String(keywordValueSplit[1])
            case "size":
                size = Int(keywordValueSplit[1])
            case "uid":
                uid = Int(keywordValueSplit[1])
            case "uname":
                uname = String(keywordValueSplit[1])
            default:
                unknownEntries[String(keywordValueSplit[0])] = String(keywordValueSplit[1])
            }
        }

        self.atime = atime
        self.charset = charset
        self.ctime = ctime
        self.mtime = mtime
        self.comment = comment
        self.gid = gid
        self.gname = gname
        //        self.hdrcharset = TODO:
        self.linkpath = linkpath
        self.path = path
        self.size = size
        self.uid = uid
        self.uname = uname

        self.unknownEntries = unknownEntries
    }

}
