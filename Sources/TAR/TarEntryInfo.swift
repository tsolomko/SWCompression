// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public struct TarEntryInfo: ContainerEntryInfo {

    // MARK: ContainerEntryInfo

    // TODO: Describe order in which formats' features are used to set this property.
    /// Name of the file or directory.
    public let name: String?

    /// Size of the data associated with the entry.
    public let size: Int?

    public let type: ContainerEntryType

    /// The most recent access time of the original file or directory (PAX only).
    public let accessTime: Date?

    /// The creation time of the original file or directory (PAX only).
    public let creationTime: Date?

    /// The most recent modification time of the original file or directory.
    public let modificationTime: Date?

    // MARK: TAR specific

    public let permissions: Permissions
    
    /// Owner's ID.
    public let ownerID: Int?
    
    /// Owner's group ID.
    public let groupID: Int?

    /// Owner's user name.
    public let ownerUserName: String?

    /// Owner's group name.
    public let ownerGroupName: String?

    public let deviceMajorNumber: Int?

    public let deviceMinorNumber: Int?

    /// Name of the character set used to encode entry's data (PAX only).
    public let charset: String?

    /// Comment associated with the entry (PAX only).
    public let comment: String?

    // TODO: Describe order in which formats' features are used to set this property.
    /// Path to a linked file for symbolic link entry.
    public let linkName: String?

    let isGlobalExtendedHeader: Bool
    let isLocalExtendedHeader: Bool
    let isLongLinkName: Bool
    let isLongName: Bool

    let blockStartIndex: Int

    init(_ pointerData: DataWithPointer, _ global: TarExtendedHeader?, _ local: TarExtendedHeader?,
         _ longName: String?, _ longLinkName: String?) throws {
        blockStartIndex = pointerData.index
        var linkName: String?
        var name: String?

        // File name
        name = try pointerData.nullEndedAsciiString(cutoff: 100)

        // File mode
        guard let octalPosixAttributes = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))?.octalToDecimal()
            else { throw TarError.fieldIsNotNumber }
        // Sometimes file mode also contains unix type, so we need to filter it out.
        let posixAttributes = UInt32(truncatingIfNeeded: octalPosixAttributes)
        permissions = Permissions(rawValue: posixAttributes & 0xFFF)
        
        // Owner's user ID
        guard let ownerAccountID = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        // There might be a PAX extended header with "uid" attribute.
        if let uidString = local?.entries["uid"] ?? global?.entries["uid"] {
            ownerID = Int(uidString)
        } else {
            ownerID = ownerAccountID
        }

        // Group's user ID
        guard let groupAccountID = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        // There might be a PAX extended header with "gid" attribute.
        if let gidString = local?.entries["gid"] ?? global?.entries["gid"] {
            groupID = Int(gidString)
        } else {
            groupID = groupAccountID
        }

        // File size
        guard let octalFileSize = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))
            else { throw TarError.fieldIsNotNumber }
        // There might be a PAX extended header with "size" attribute.
        if let sizeString = local?.entries["size"] ?? global?.entries["size"] {
            size = Int(sizeString)
        } else {
            size = octalFileSize.octalToDecimal()
        }

        // Modification time
        guard let mtime = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))?.octalToDecimal()
            else { throw TarError.fieldIsNotNumber }
        if let mtimeString = local?.entries["mtime"] ?? global?.entries["mtime"], let paxMtime = Double(mtimeString) {
            self.modificationTime = Date(timeIntervalSince1970: paxMtime)
        } else {
            modificationTime = Date(timeIntervalSince1970: TimeInterval(mtime))
        }

        // Checksum
        guard let checksum = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))?.octalToDecimal()
            else { throw TarError.fieldIsNotNumber }

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
        let fileTypeIndicator = pointerData.byte()
        self.isGlobalExtendedHeader = fileTypeIndicator == 103 // "g"
        self.isLocalExtendedHeader = fileTypeIndicator == 120 // "x"
        self.isLongLinkName = fileTypeIndicator == 75 // "K"
        self.isLongName =  fileTypeIndicator == 76 // "L"
        self.type = ContainerEntryType(from: fileTypeIndicator)

        // Linked file name
        linkName = try pointerData.nullEndedAsciiString(cutoff: 100)

        // There are two POSIX-like formats: pre-POSIX used by GNU tools and POSIX.
        // They differ in `magic` field value and how other fields are padded.
        // Padding is taken care of in Data extension functions in "DataWithPointer+Tar.swift" file.
        // Here we deal with magic. First one is of pre-POSIX, second and third are two variations of POSIX.
        let magic = pointerData.bytes(count: 8)

        if magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x20, 0x20, 0x00] ||
            magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x00, 0x30, 0x30] ||
            magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x20, 0x30, 0x30] {
            if let uname = local?.entries["uname"] ?? global?.entries["uname"] {
                self.ownerUserName = uname
                pointerData.index += 32
            } else {
                ownerUserName = try pointerData.nullEndedAsciiString(cutoff: 32)
            }

            if let gname = local?.entries["gname"] ?? global?.entries["gname"] {
                ownerGroupName = gname
                pointerData.index += 32
            } else {
                ownerGroupName = try pointerData.nullEndedAsciiString(cutoff: 32)
            }

            deviceMajorNumber = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            deviceMinorNumber = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            name = try pointerData.nullEndedAsciiString(cutoff: 155) + (name ?? "")
        } else {
            ownerUserName = local?.entries["uname"] ?? global?.entries["uname"]
            ownerGroupName = local?.entries["gname"] ?? global?.entries["gname"]
            deviceMajorNumber = nil
            deviceMinorNumber = nil
        }

        // Set `name` and `linkName` to values from PAX or GNU format if possible.
        self.name = ((local?.entries["path"] ?? global?.entries["path"]) ?? longName) ?? name
        self.linkName = ((local?.entries["linkpath"] ?? global?.entries["linkpath"]) ?? longLinkName) ?? linkName
        
        // Set additional properties from PAX extended headers.
        if let atimeString = local?.entries["atime"] ?? global?.entries["atime"], let atime = Double(atimeString) {
            accessTime = Date(timeIntervalSince1970: atime)
        } else {
            accessTime = nil
        }
        
        if let ctimeString = local?.entries["ctime"] ?? global?.entries["ctime"], let ctime = Double(ctimeString) {
            creationTime = Date(timeIntervalSince1970: ctime)
        } else {
            creationTime = nil
        }

        charset = local?.entries["charset"] ?? global?.entries["charset"]
        comment =  local?.entries["comment"] ?? global?.entries["comment"]
    }

}
