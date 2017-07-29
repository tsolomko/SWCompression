// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents either a file or directory entry in TAR container.
public class TarEntry: ContainerEntry {

    /**
     Represents a type of an entry.

     - Warning:
     Deprecated and will be removed in 4.0. `FileAttributeType` values will be used instead.
     */
    public enum EntryType: String {
        /// Normal file.
        case normal = "0"
        /// Hard linked entry.
        case hardLink = "1"
        /// Symbolically linked entry.
        case symbolicLink = "2"
        /// Character special file.
        case characterSpecial = "3"
        /// Block special file.
        case blockSpecial = "4"
        /// Directory.
        case directory = "5"
        /// FIFO special file.
        case fifo = "6"
        /// Contiguous file.
        case contiguous = "7"
        /// PAX global extended header. (Should not be encountered separately).
        case globalExtendedHeader = "g"
        /// PAX local extended header. (Should not be encountered separately).
        case localExtendedHeader = "x"
        /// Either unknown type, vendor specific or reserved value.
        case vendorUnknownOrReserved
    }

    /// Name of the file or directory.
    public var name: String {
        return (paxPath ?? gnuLongName) ?? ((fileNamePrefix ?? "") + (fileName ?? ""))
    }

    /// True, if an entry is a directory.
    public var isDirectory: Bool {
        return (type == .directory) || (type == .normal && size == 0 && name.characters.last == "/")
    }

    /// Size of the data associated with the entry.
    public private(set) var size: Int

    /**
     Provides a dictionary with various attributes of the entry.
     `FileAttributeKey` values are used as dictionary keys.

     - Note:
     Will be renamed in 4.0.

     ## Possible attributes:

     - `FileAttributeKey.posixPermissions`,
     - `FileAttributeKey.ownerAccountID`,
     - `FileAttributeKey.groupOwnerAccountID`,
     - `FileAttributeKey.size`,
     - `FileAttributeKey.modificationDate`,
     - `FileAttributeKey.type`,
     - `FileAttributeKey.ownerAccountName`, if format of container is UStar,
     - `FileAttributeKey.groupOwnerAccountName`, if format of container is UStar,
     - `FileAttributeKey.creationDate`, if format of container is PAX.

     Most modern TAR containers are in UStar format.
     */
    public let entryAttributes: [FileAttributeKey: Any]

    /**
     File mode.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public let mode: Int?

    /**
     Owner's ID.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public private(set) var ownerID: Int?

    /**
     Owner's group ID.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public private(set) var groupID: Int?

    /**
     The most recent modification time of the original file or directory.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public private(set) var modificationTime: Date

    /**
     Type of entry.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public let type: EntryType

    /**
     Owner's user name.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public private(set) var ownerUserName: String?

    /**
     Owner's group name.

     - Warning:
     Deprecated and will be removed in 4.0. Use `entryAttributes` instead.
     */
    public private(set) var ownerGroupName: String?

    private let deviceMajorNumber: String?
    private let deviceMinorNumber: String?

    private let fileName: String?
    private let fileNamePrefix: String?
    private let linkedFileName: String?
    private var paxPath: String?

    /// The most recent access time of the original file or directory (PAX only).
    public private(set) var accessTime: Date?

    /// The creation time of the original file or directory (PAX only).
    public private(set) var creationTime: Date?

    /// Name of the character set used to encode entry's data (PAX only).
    public private(set) var charset: String?

    /// Comment associated with the entry (PAX only).
    public private(set) var comment: String?

    /// Path to a linked file.
    public var linkPath: String? {
        return (paxLinkPath ?? gnuLongLinkName) ?? linkedFileName
    }

    private var paxLinkPath: String?

    /// Other entries from PAX extended headers.
    public private(set) var unknownExtendedHeaderEntries: [String: String] = [:]

    /// Returns data associated with this entry.
    public func data() -> Data {
        return dataObject
    }

    private let dataObject: Data

    private let gnuLongName: String?
    private let gnuLongLinkName: String?

    init(_ pointerData: DataWithPointer, _ globalExtendedHeader: String?, _ localExtendedHeader: String?,
         _ longName: String?, _ longLinkName: String?) throws {
        if let longName = longName {
            gnuLongName = longName
        } else {
            gnuLongName = nil
        }
        if let longLinkName = longLinkName {
            gnuLongLinkName = longLinkName
        } else {
            gnuLongLinkName = nil
        }

        var attributesDict = [FileAttributeKey: Any]()

        let blockStartIndex = pointerData.index
        // File name
        fileName = try pointerData.nullEndedAsciiString(cutoff: 100)

        // File mode
        guard let octalPosixPermissions = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        let posixPermissions = octalPosixPermissions.octalToDecimal()
        attributesDict[FileAttributeKey.posixPermissions] = posixPermissions
        mode = posixPermissions

        // Owner's user ID
        guard let ownerAccountID = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        attributesDict[FileAttributeKey.ownerAccountID] = ownerAccountID
        ownerID = ownerAccountID

        // Group's user ID
        guard let groupAccountID = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        attributesDict[FileAttributeKey.groupOwnerAccountID] = groupAccountID
        groupID = groupAccountID

        // File size
        guard let octalFileSize = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))
            else { throw TarError.fieldIsNotNumber }
        let fileSize = octalFileSize.octalToDecimal()
        attributesDict[FileAttributeKey.size] = fileSize
        size = fileSize

        // Modification time
        guard let octalMtime = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))
            else { throw TarError.fieldIsNotNumber }
        let mtime = Date(timeIntervalSince1970: TimeInterval(octalMtime.octalToDecimal()))
        attributesDict[FileAttributeKey.modificationDate] = mtime
        modificationTime = mtime

        // Checksum
        guard let octalChecksum = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        let checksum = octalChecksum.octalToDecimal()

        // TODO: Change subdata to slicing in Swift 4.0.
        let currentIndex = pointerData.index
        pointerData.index = blockStartIndex
        var headerDataForChecksum = pointerData.bytes(count: 512)
        for i in 148..<156 {
            headerDataForChecksum[i] = 0x20
        }
        pointerData.index = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, coincedence in one of them will pass the checksum test.
        let unsignedOurChecksumArray = headerDataForChecksum.map { UInt($0) }
        let signedOurChecksumArray = headerDataForChecksum.map { Int($0) }

        let unsignedOurChecksum = unsignedOurChecksumArray.reduce(0) { $0 + $1 }
        let signedOurChecksum = signedOurChecksumArray.reduce(0) { $0 + $1 }
        guard unsignedOurChecksum == UInt(checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        // File type
        let fileTypeIndicator = String(Character(UnicodeScalar(pointerData.byte())))
        let fileType = EntryType(rawValue: fileTypeIndicator) ?? .vendorUnknownOrReserved
        type = fileType
        switch fileType {
        case .normal:
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
        case .symbolicLink:
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeSymbolicLink
        case .characterSpecial:
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeCharacterSpecial
        case .blockSpecial:
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeBlockSpecial
        case .directory:
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
        default:
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeUnknown
        }

        // Linked file name
        linkedFileName = try pointerData.nullEndedAsciiString(cutoff: 100)

        // There are two POSIX-like formats: pre-POSIX used by GNU tools and POSIX.
        // They differ in `magic` field value and how other fields are padded.
        // Padding is taken care of in Data extension functions at the end of this file.
        // Here we deal with magic. First one is of pre-POSIX, second and third are two variations of POSIX.
        let magic = pointerData.bytes(count: 8)

        if magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x20, 0x20, 0x00] ||
            magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x00, 0x30, 0x30] ||
            magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x20, 0x30, 0x30] {
            let ownerName = try pointerData.nullEndedAsciiString(cutoff: 32)
            attributesDict[FileAttributeKey.ownerAccountName] = ownerName
            ownerUserName = ownerName

            let groupName = try pointerData.nullEndedAsciiString(cutoff: 32)
            attributesDict[FileAttributeKey.groupOwnerAccountName] = groupName
            ownerGroupName = groupName

            deviceMajorNumber = try pointerData.nullSpaceEndedAsciiString(cutoff: 8)
            deviceMinorNumber = try pointerData.nullSpaceEndedAsciiString(cutoff: 8)
            fileNamePrefix = try pointerData.nullEndedAsciiString(cutoff: 155)
        } else {
            ownerUserName = nil
            ownerGroupName = nil
            deviceMajorNumber = nil
            deviceMinorNumber = nil
            fileNamePrefix = nil
        }

        var fieldsDict = [String: String]()
        try TarEntry.parseHeader(globalExtendedHeader, &fieldsDict)
        try TarEntry.parseHeader(localExtendedHeader, &fieldsDict)

        for (keyword, value) in fieldsDict {
            switch keyword {
            case "atime":
                if let interval = Double(value) {
                    self.accessTime = Date(timeIntervalSince1970: interval)
                }
            case "charset":
                self.charset = value
            case "ctime":
                if let interval = Double(value) {
                    let ctime = Date(timeIntervalSince1970: interval)
                    attributesDict[FileAttributeKey.creationDate] = ctime
                    self.creationTime = ctime
                }
            case "mtime":
                if let interval = Double(value) {
                    let newMtime = Date(timeIntervalSince1970: interval)
                    attributesDict[FileAttributeKey.modificationDate] = newMtime
                    self.modificationTime = newMtime
                }
            case "comment":
                self.comment = value
            case "gid":
                if let newValue = Int(value) {
                    attributesDict[FileAttributeKey.groupOwnerAccountID] = newValue
                }
                self.groupID = Int(value)
            case "gname":
                attributesDict[FileAttributeKey.groupOwnerAccountName] = value
                self.ownerGroupName = value
            case "hdrcharset":
                break
            case "linkpath":
                self.paxLinkPath = value
            case "path":
                self.paxPath = value
            case "size":
                if let intValue = Int(value) {
                    self.size = intValue
                }
            case "uid":
                if let newValue = Int(value) {
                    attributesDict[FileAttributeKey.ownerAccountID] = newValue
                }
                self.ownerID = Int(value)
            case "uname":
                attributesDict[FileAttributeKey.ownerAccountName] = value
                self.ownerUserName = value
            default:
                self.unknownExtendedHeaderEntries[keyword] = value
            }
        }

        self.entryAttributes = attributesDict

        // File data
        pointerData.index = blockStartIndex + 512
        self.dataObject = Data(bytes: pointerData.bytes(count: size))
        pointerData.index -= size
        pointerData.index += size.roundTo512()
    }

    private static func parseHeader(_ header: String?, _ fieldsDict: inout [String: String]) throws {
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

}

extension DataWithPointer {

    func nullEndedBuffer(cutoff: Int) -> [UInt8] {
        let startIndex = index
        var buffer = [UInt8]()
        while index - startIndex < cutoff {
            let byte = self.byte()
            if byte == 0 {
                index -= 1
                break
            }
            buffer.append(byte)
        }
        index += cutoff - (index - startIndex)
        return buffer
    }

    func nullEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.nullEndedBuffer(cutoff: cutoff), encoding: .ascii) {
            return string
        } else {
            throw TarError.notAsciiString
        }
    }

    func nullSpaceEndedBuffer(cutoff: Int) -> [UInt8] {
        let startIndex = index
        var buffer = [UInt8]()
        while index - startIndex < cutoff {
            let byte = self.byte()
            if byte == 0 || byte == 0x20 {
                index -= 1
                break
            }
            buffer.append(byte)
        }
        index += cutoff - (index - startIndex)
        return buffer
    }

    func nullSpaceEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.nullSpaceEndedBuffer(cutoff: cutoff), encoding: .ascii) {
            return string
        } else {
            throw TarError.notAsciiString
        }
    }

}

extension Int {

    func octalToDecimal() -> Int {
        var octal = self
        var decimal = 0, i = 0
        while octal != 0 {
            let remainder = octal % 10
            octal /= 10
            decimal += remainder * Int(pow(8, Double(i)))
            i += 1
        }
        return decimal
    }

    func roundTo512() -> Int {
        let fractionNum = Double(self) / 512
        let roundedNum = Int(ceil(fractionNum))
        return roundedNum * 512
    }

}
