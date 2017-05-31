//
//  TarContainer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 05.05.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during processing TAR archive (container).
 It may indicate that either the data is damaged or it might not be TAR archive (container) at all.

 - `error`: error description.
 */
public enum TarError: Error {
    case tooSmallFileIsPassed
    case fieldIsNotNumber
    case wrongHeaderChecksum
    case wrongUstarVersion
    case wrongPaxHeaderEntry
    case notAsciiString
}

/// Represents either a file or directory entry inside TAR archive.
public class TarEntry: ContainerEntry {

    public enum EntryType: String {
        case normal = "0"
        case hardLink = "1"
        case symbolicLink = "2"
        case characterSpecial = "3"
        case blockSpecial = "4"
        case directory = "5"
        case fifo = "6"
        case contiguous = "7"
        case globalExtendedHeader = "g"
        case localExtendedHeader = "x"
        case vendorUnknownOrReserved
    }

    /// Name of the file or directory.
    public var name: String {
        return paxPath ?? ((fileNamePrefix ?? "") + (fileName ?? ""))
    }

    public var isDirectory: Bool {
        return (type == .directory) || (type == .normal && size == 0 && name.characters.last == "/")
    }

    public let mode: Int?
    public private(set) var ownerID: Int?
    public private(set) var groupID: Int?
    public private(set) var size: Int
    public private(set) var modificationTime: Date
    public let type: EntryType

    public private(set) var ownerUserName: String?
    public private(set) var ownerGroupName: String?
    private let deviceMajorNumber: String?
    private let deviceMinorNumber: String?

    private let fileName: String?
    private let fileNamePrefix: String?
    private let linkedFileName: String?

    private let dataObject: Data

    public private(set) var accessTime: Date?
    public private(set) var charset: String?
    public private(set) var comment: String?
    public private(set) var linkPath: String?
    public private(set) var unknownExtendedHeaderEntries: [String: String] = [:]
    private var paxPath: String?

    fileprivate init(_ data: Data, _ index: inout Int,
                     _ globalExtendedHeader: String?, _ localExtendedHeader: String?) throws {
        let blockStartIndex = index
        // File name
        fileName = try data.nullEndedAsciiString(index, 100)
        index += 100

        // File mode
        mode = Int(try data.nullSpaceEndedAsciiString(index, 8))
        index += 8

        // Owner's user ID
        ownerID = Int(try data.nullSpaceEndedAsciiString(index, 8))
        index += 8

        // Group's user ID
        groupID = Int(try data.nullSpaceEndedAsciiString(index, 8))
        index += 8

        // File size
        guard let octalFileSize = Int(try data.nullSpaceEndedAsciiString(index, 12))
            else { throw TarError.fieldIsNotNumber }
        size = octalToDecimal(octalFileSize)
        index += 12

        // Modification time
        guard let octalMtime = Int(try data.nullSpaceEndedAsciiString(index, 12))
            else { throw TarError.fieldIsNotNumber }
        modificationTime = Date(timeIntervalSince1970: TimeInterval(octalToDecimal(octalMtime)))
        index += 12

        // Checksum
        guard let octalChecksum = Int(try data.nullSpaceEndedAsciiString(index, 8))
            else { throw TarError.fieldIsNotNumber }
        let checksum = octalToDecimal(octalChecksum)

        var headerDataForChecksum = data.subdata(in: blockStartIndex..<blockStartIndex + 512).toArray(type: UInt8.self)
        for i in 148..<156 {
            headerDataForChecksum[i] = 0x20
        }

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, coincedence in one of them will pass the checksum test.
        let unsignedOurChecksumArray = headerDataForChecksum.map { UInt($0) }
        let signedOurChecksumArray = headerDataForChecksum.map { Int($0) }

        let unsignedOurChecksum = unsignedOurChecksumArray.reduce(0) { $0 + $1 }
        let signedOurChecksum = signedOurChecksumArray.reduce(0) { $0 + $1 }
        guard unsignedOurChecksum == UInt(checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        index += 8

        // File type
        type = EntryType(rawValue: String(Character(UnicodeScalar(data[index])))) ?? .vendorUnknownOrReserved
        index += 1

        // Linked file name
        linkedFileName = try data.nullEndedAsciiString(index, 100)
        index += 100

        let posixIndicator = String(data: data.subdata(in: 257..<263), encoding: .ascii)
        if posixIndicator == "ustar\u{00}" || posixIndicator == "ustar\u{20}" {
            index += 6

            let ustarVersion = String(data: data.subdata(in: index..<index + 2), encoding: .ascii)
            guard ustarVersion == "00" else { throw TarError.wrongUstarVersion }
            index += 2

            ownerUserName = try data.nullEndedAsciiString(index, 32)
            index += 32

            ownerGroupName = try data.nullEndedAsciiString(index, 32)
            index += 32

            deviceMajorNumber = try data.nullSpaceEndedAsciiString(index, 8)
            index += 8

            deviceMinorNumber = try data.nullSpaceEndedAsciiString(index, 8)
            index += 8

            fileNamePrefix = try data.nullEndedAsciiString(index, 155)
            index += 155
        } else {
            ownerUserName = nil
            ownerGroupName = nil
            deviceMajorNumber = nil
            deviceMinorNumber = nil
            fileNamePrefix = nil
        }

        func parseHeader(_ header: String?, _ fieldsDict: inout [String : String]) throws {
            if let headerString = header {
                let headerEntries = headerString.components(separatedBy: "\n")
                for headerEntry in headerEntries {
                    if headerEntry == "" {
                        continue
                    }
                    let headerEntrySplit = headerEntry.characters.split(separator: " ", maxSplits: 1,
                                                                        omittingEmptySubsequences: false)
                    guard Int(String(headerEntrySplit[0])) == headerEntry.characters.count + 1
                        else { throw TarError.wrongPaxHeaderEntry }
                    let keywordValue = String(headerEntrySplit[1])
                    let keywordValueSplit = keywordValue.characters.split(separator: "=", maxSplits: 1,
                                                                          omittingEmptySubsequences: false)
                    let keyword = String(keywordValueSplit[0])
                    let value = String(keywordValueSplit[1])
                    fieldsDict[keyword] = value
                }
            }
        }

        var fieldsDict = [String: String]()
        try parseHeader(globalExtendedHeader, &fieldsDict)
        try parseHeader(localExtendedHeader, &fieldsDict)

        for (keyword, value) in fieldsDict {
            switch keyword {
            case "atime":
                if let interval = Double(value) {
                    self.accessTime = Date(timeIntervalSince1970: interval)
                }
            case "charset":
                self.charset = value
            case "mtime":
                if let interval = Double(value) {
                    self.modificationTime = Date(timeIntervalSince1970: interval)
                }
            case "comment":
                self.comment = value
            case "gid":
                self.groupID = Int(value)
            case "gname":
                self.ownerGroupName = value
            case "hdrcharset":
                break
            case "linkpath":
                self.linkPath = value
            case "path":
                self.paxPath = value
            case "size":
                if let intValue = Int(value) {
                    self.size = intValue
                }
            case "uid":
                self.ownerID = Int(value)
            case "uname":
                self.ownerUserName = value
            default:
                self.unknownExtendedHeaderEntries[keyword] = value
            }
        }

        // File data
        index = blockStartIndex + 512
        self.dataObject = data.subdata(in: index..<index + size)
        index += size
        index = roundTo512(value: index)
    }

    /**
     Returns data associated with this entry.

     - Note: Returned `Data` object with the size of 0 can either indicate that the entry is an empty file
     or it is a directory.
     */
    public func data() -> Data {
        return dataObject
    }

}

/// Provides function which opens TAR archives (containers).
public class TarContainer: Container {

    public static func open(container data: Data) throws -> [ContainerEntry] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        var output = [TarEntry]()

        var index = 0

        var lastGlobalExtendedHeader: String?
        var lastLocalExtendedHeader: String?

        while true {
            // Container ends with two zero-filled records.
            if data.subdata(in: index..<index + 1024) == Data(bytes: Array(repeating: 0, count: 1024)) {
                break
            }
            let entry = try TarEntry(data, &index, lastGlobalExtendedHeader, lastLocalExtendedHeader)
            switch entry.type {
            case .globalExtendedHeader:
                lastGlobalExtendedHeader = String(data: entry.data(), encoding: .utf8)
            case .localExtendedHeader:
                lastLocalExtendedHeader = String(data: entry.data(), encoding: .utf8)
            default:
                output.append(entry)
                lastLocalExtendedHeader = nil
            }
        }

        return output
    }

}

fileprivate extension Data {

    fileprivate func nullEndedBuffer(_ startIndex: Int, _ cutoff: Int) -> [UInt8] {
        var index = startIndex
        var buffer = [UInt8]()
        while true {
            if self[index] == 0 || index - startIndex >= cutoff {
                break
            }
            buffer.append(self[index])
            index += 1
        }
        return buffer
    }

    fileprivate func nullEndedAsciiString(_ startIndex: Int, _ cutoff: Int) throws -> String {
        if let string = String(bytes: self.nullEndedBuffer(startIndex, cutoff), encoding: .ascii) {
            return string
        } else {
            throw TarError.notAsciiString
        }
    }

    fileprivate func nullSpaceEndedBuffer(_ startIndex: Int, _ cutoff: Int) -> [UInt8] {
        var index = startIndex
        var buffer = [UInt8]()
        while true {
            if self[index] == 0 || self[index] == 0x20 || index - startIndex >= cutoff {
                break
            }
            buffer.append(self[index])
            index += 1
        }
        return buffer
    }

    fileprivate func nullSpaceEndedAsciiString(_ startIndex: Int, _ cutoff: Int) throws -> String {
        if let string = String(bytes: self.nullSpaceEndedBuffer(startIndex, cutoff), encoding: .ascii) {
            return string
        } else {
            throw TarError.notAsciiString
        }
    }

}

fileprivate func octalToDecimal(_ number: Int) -> Int {
    var octal = number
    var decimal = 0, i = 0
    while octal != 0 {
        let remainder = octal % 10
        octal /= 10
        decimal += remainder * Int(pow(8, Double(i)))
        i += 1
    }
    return decimal
}

fileprivate func roundTo512(value: Int) -> Int {
    let fractionNum = Double(value) / 512
    let roundedNum = Int(ceil(fractionNum))
    return roundedNum * 512
}
