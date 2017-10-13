// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class TarEntryInfo: ContainerEntryInfo {

    // MARK: ContainerEntryInfo

    // TODO: Describe order in which formats' features are used to set this property.
    /// Name of the file or directory.
    public let name: String?

    /// Size of the data associated with the entry.
    public private(set) var size: Int?

    public let type: ContainerEntryType

    // MARK: TAR specific

    public let permissions: Permissions

    public let unixType: UnixType?

    /**
     Owner's ID.
     */
    public private(set) var ownerID: Int?

    /**
     Owner's group ID.
     */
    public private(set) var groupID: Int?

    /**
     The most recent modification time of the original file or directory.
     */
    public private(set) var modificationTime: Date

    /**
     Owner's user name.
     */
    public private(set) var ownerUserName: String?

    /**
     Owner's group name.
     */
    public private(set) var ownerGroupName: String?

    public let deviceMajorNumber: Int?

    public let deviceMinorNumber: Int?

    /// The most recent access time of the original file or directory (PAX only).
    public private(set) var accessTime: Date?

    /// The creation time of the original file or directory (PAX only).
    public private(set) var creationTime: Date?

    /// Name of the character set used to encode entry's data (PAX only).
    public private(set) var charset: String?

    /// Comment associated with the entry (PAX only).
    public private(set) var comment: String?

    // TODO: Describe order in which formats' features are used to set this property.
    /// Path to a linked file for symbolic link entry.
    public let linkName: String?

    /// Other entries from PAX extended headers.
    public private(set) var unknownExtendedHeaderEntries: [String: String] = [:]

    let isGlobalExtendedHeader: Bool
    let isLocalExtendedHeader: Bool

    let blockStartIndex: Int

    init(_ pointerData: DataWithPointer, _ global: TarExtendedHeader?, _ local: TarExtendedHeader?,
         _ longName: String?, _ longLinkName: String?) throws {
        self.blockStartIndex = pointerData.index
        var linkName: String?
        var name: String?

        // File name
        name = try pointerData.nullEndedAsciiString(cutoff: 100)

        // File mode
        guard let octalPosixAttributes = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        // Sometime file mode also contains unix type, so we need to filter it out.
        let posixAttributes = UInt32(truncatingIfNeeded: octalPosixAttributes.octalToDecimal())
        permissions = Permissions(rawValue: posixAttributes & 0xFFF)
        unixType = UnixType(rawValue: posixAttributes & 0xF000)

        // Owner's user ID
        guard let ownerAccountID = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        ownerID = ownerAccountID

        // Group's user ID
        guard let groupAccountID = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        groupID = groupAccountID

        // File size
        guard let octalFileSize = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))
            else { throw TarError.fieldIsNotNumber }
        size = octalFileSize.octalToDecimal()

        // Modification time
        guard let octalMtime = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))
            else { throw TarError.fieldIsNotNumber }
        modificationTime = Date(timeIntervalSince1970: TimeInterval(octalMtime.octalToDecimal()))

        // Checksum
        guard let octalChecksum = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.fieldIsNotNumber }
        let checksum = octalChecksum.octalToDecimal()

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
        // TODO: Don't convert to String.
        let fileTypeIndicator = pointerData.byte()
        self.isGlobalExtendedHeader = fileTypeIndicator == 103 // "g"
        self.isLocalExtendedHeader = fileTypeIndicator == 120 // "x"
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
            ownerUserName = try pointerData.nullEndedAsciiString(cutoff: 32)
            ownerGroupName = try pointerData.nullEndedAsciiString(cutoff: 32)

            deviceMajorNumber = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            deviceMinorNumber = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 8))
            name = try pointerData.nullEndedAsciiString(cutoff: 155) + (name ?? "")
        } else {
            ownerUserName = nil
            ownerGroupName = nil
            deviceMajorNumber = nil
            deviceMinorNumber = nil
        }

        // Set `name` and `linkName` to values from GNU format if possible.
        name = longName ?? name
        linkName = longLinkName ?? linkName
        
        // Set properties from PAX extended headers.
        if let globalAtimeString = global?.entries["atime"], let globalAtime = Double(globalAtimeString) {
            self.accessTime = Date(timeIntervalSince1970: globalAtime)
        }
        if let localAtimeString = local?.entries["atime"], let localAtime = Double(localAtimeString) {
            self.accessTime = Date(timeIntervalSince1970: localAtime)
        }
        
        if let globalCtimeString = global?.entries["ctime"], let globalCtime = Double(globalCtimeString) {
            self.creationTime = Date(timeIntervalSince1970: globalCtime)
        }
        if let localCtimeString = local?.entries["ctime"], let localCtime = Double(localCtimeString) {
            self.creationTime = Date(timeIntervalSince1970: localCtime)
        }
        
        // TODO: mtime and some other properties will need special treatment to make it constant.
        if let globalMtimeString = global?.entries["mtime"], let globalMtime = Double(globalMtimeString) {
            self.modificationTime = Date(timeIntervalSince1970: globalMtime)
        }
        if let localMtimeString = local?.entries["mtime"], let localMtime = Double(localMtimeString) {
            self.modificationTime = Date(timeIntervalSince1970: localMtime)
        }
        
        if let globalCharset = global?.entries["charset"] {
            self.charset = globalCharset
        }
        if let localCharset = local?.entries["charset"] {
            self.charset = localCharset
        }
        
        if let globalComment = global?.entries["comment"] {
            self.comment = globalComment
        }
        if let localComment = local?.entries["comment"] {
            self.comment = localComment
        }
        
        if let globalLinkpath = global?.entries["linkpath"] {
            linkName = globalLinkpath
        }
        if let localLinkpath = local?.entries["linkpath"] {
            linkName = localLinkpath
        }
        
        if let globalPath = global?.entries["path"] {
            name = globalPath
        }
        if let localPath = local?.entries["path"] {
            name = localPath
        }
        
        if let globalGidString = global?.entries["gid"] {
            self.groupID = Int(globalGidString)
        }
        if let localGidString = local?.entries["gid"] {
            self.groupID = Int(localGidString)
        }
        
        if let globalUidString = global?.entries["uid"] {
            self.ownerID = Int(globalUidString)
        }
        if let localUidString = local?.entries["uid"] {
            self.ownerID = Int(localUidString)
        }
        
        if let globalSizeString = global?.entries["size"] {
            self.size = Int(globalSizeString)
        }
        if let localSizeString = local?.entries["size"] {
            self.size = Int(localSizeString)
        }
        
        if let globalGname = global?.entries["gname"] {
            self.ownerGroupName = globalGname
        }
        if let localGname = local?.entries["gname"] {
            self.ownerGroupName = localGname
        }
        
        if let globalUname = global?.entries["uname"] {
            self.ownerUserName = globalUname
        }
        if let localUname = local?.entries["uname"] {
            self.ownerUserName = localUname
        }

        self.name = name
        self.linkName = linkName
    }

}
