// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides access to information about an entry from the TAR container.
public struct TarEntryInfo: ContainerEntryInfo {

    // MARK: ContainerEntryInfo

    /**
     Entry's name.

     Depending on the particular format of the container, different container's structures are used
     to set this property, in the following preference order:
     1. Local PAX extended header "path" property.
     2. Global PAX extended header "path" property.
     3. GNU format type "L" (LongName) entry.
     4. Default TAR header.
     */
    public let name: String

    /// Entry's data size.
    public let size: Int?

    public let type: ContainerEntryType

    /// Entry's last access time (only available for PAX format; `nil` otherwise).
    public let accessTime: Date?

    /// Entry's creation time (only available for PAX format; `nil` otherwise).
    public let creationTime: Date?

    /// Entry's last modification time.
    public let modificationTime: Date?

    public let permissions: Permissions?

    // MARK: TAR specific

    /// ID of entry's owner.
    public let ownerID: Int?

    /// ID of the group of entry's owner.
    public let groupID: Int?

    /// User name of entry's owner.
    public let ownerUserName: String?

    /// Name of the group of entry's owner.
    public let ownerGroupName: String?

    /// Device major number (used when entry is either block or character special file).
    public let deviceMajorNumber: Int?

    /// Device minor number (used when entry is either block or character special file).
    public let deviceMinorNumber: Int?

    /// Name of the character set used to encode entry's data (only available for PAX format; `nil` otherwise).
    public let charset: String?

    /// Entry's comment (only available for PAX format; `nil` otherwise).
    public let comment: String?

    /**
     Path to a linked file for symbolic link entry.

     Depending on the particular format of the container, different container's structures are used
     to set this property, in the following preference order:
     1. Local PAX extended header "linkpath" property.
     2. Global PAX extended header "linkpath" property.
     3. GNU format type "K" (LongLink) entry.
     4. Default TAR header.
     */
    public let linkName: String

    public let unknownExtendedHeaderRecords: [String: String]?

    let isGlobalExtendedHeader: Bool
    let isLocalExtendedHeader: Bool
    let isLongLinkName: Bool
    let isLongName: Bool

    let blockStartIndex: Int

    init(_ byteReader: ByteReader, _ global: TarExtendedHeader?, _ local: TarExtendedHeader?,
         _ longName: String?, _ longLinkName: String?) throws {
        blockStartIndex = byteReader.offset
        var linkName: String
        var name: String

        // File name
        name = try byteReader.nullEndedAsciiString(cutoff: 100)

        // File mode
        guard let posixAttributes = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 8), radix: 8)
            else { throw TarError.wrongField }
        // Sometimes file mode also contains unix type, so we need to filter it out.
        permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixAttributes) & 0xFFF)

        // Owner's user ID
        guard let ownerAccountID = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.wrongField }
        // There might be a PAX extended header with "uid" attribute.
        ownerID = (local?.uid ?? global?.uid) ?? ownerAccountID

        // Group's user ID
        guard let groupAccountID = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 8))
            else { throw TarError.wrongField }
        // There might be a PAX extended header with "gid" attribute.
        groupID = (local?.gid ?? global?.gid) ?? groupAccountID

        // File size
        guard let fileSize = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 12), radix: 8)
            else { throw TarError.wrongField }
        // There might be a PAX extended header with "size" attribute.
        size = (local?.size ?? global?.size) ?? fileSize

        // Modification time
        guard let mtime = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 12), radix: 8)
            else { throw TarError.wrongField }
        if let paxMtime = local?.mtime ?? global?.mtime {
            modificationTime = Date(timeIntervalSince1970: paxMtime)
        } else {
            modificationTime = Date(timeIntervalSince1970: TimeInterval(mtime))
        }

        // Checksum
        guard let checksum = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 8), radix: 8)
            else { throw TarError.wrongField }

        let currentIndex = byteReader.offset
        byteReader.offset = blockStartIndex
        var headerDataForChecksum = byteReader.bytes(count: 512)
        for i in 148..<156 {
            headerDataForChecksum[i] = 0x20
        }
        byteReader.offset = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, coincedence in one of them will pass the checksum test.
        let unsignedOurChecksumArray = headerDataForChecksum.map { UInt($0) }
        let signedOurChecksumArray = headerDataForChecksum.map { Int($0) }

        let unsignedOurChecksum = unsignedOurChecksumArray.reduce(0) { $0 + $1 }
        let signedOurChecksum = signedOurChecksumArray.reduce(0) { $0 + $1 }
        guard unsignedOurChecksum == UInt(checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        // File type
        let fileTypeIndicator = byteReader.byte()
        self.isGlobalExtendedHeader = fileTypeIndicator == 103 // "g"
        self.isLocalExtendedHeader = fileTypeIndicator == 120 // "x"
        self.isLongLinkName = fileTypeIndicator == 75 // "K"
        self.isLongName = fileTypeIndicator == 76 // "L"
        self.type = ContainerEntryType(fileTypeIndicator)

        // Linked file name
        linkName = try byteReader.nullEndedAsciiString(cutoff: 100)

        // There are two POSIX-like formats: pre-POSIX used by GNU tools (aka "old-GNU") and POSIX (aka "ustar").
        // They differ in `magic` field value and how other fields are padded (either SPACEs or NULLs).
        // Padding is taken care of in Data extension functions in "ByteReader+Tar.swift" file.
        // Here we deal with magic. First one is "old-GNU", second is "ustar", third is for compatiblity with strange
        //  implementations of "ustar", which used SPACEs instead of NULLs.
        let magic = byteReader.uint64()

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            let uname = try byteReader.nullEndedAsciiString(cutoff: 32)
            self.ownerUserName = (local?.uname ?? global?.uname) ?? uname

            let gname = try byteReader.nullEndedAsciiString(cutoff: 32)
            self.ownerGroupName = (local?.gname ?? global?.gname) ?? gname

            deviceMajorNumber = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 8))
            deviceMinorNumber = Int(try byteReader.nullSpaceEndedAsciiString(cutoff: 8))
            let prefix = try byteReader.nullEndedAsciiString(cutoff: 155)
            if prefix != "" {
                name = prefix + "/" + name
            }
        } else {
            ownerUserName = local?.uname ?? global?.uname
            ownerGroupName = local?.gname ?? global?.gname
            deviceMajorNumber = nil
            deviceMinorNumber = nil
        }

        // Set `name` and `linkName` to values from PAX or GNU format if possible.
        self.name = ((local?.path ?? global?.path) ?? longName) ?? name
        self.linkName = ((local?.linkpath ?? global?.linkpath) ?? longLinkName) ?? linkName

        // Set additional properties from PAX extended headers.
        if let atime = local?.atime ?? global?.atime {
            accessTime = Date(timeIntervalSince1970: atime)
        } else {
            accessTime = nil
        }

        if let ctime = local?.ctime ?? global?.ctime {
            creationTime = Date(timeIntervalSince1970: ctime)
        } else {
            creationTime = nil
        }

        charset = local?.charset ?? global?.charset
        comment = local?.comment ?? global?.comment
        if let localUnknownRecords = local?.unknownRecords {
            if let globalUnknownRecords = global?.unknownRecords {
                unknownExtendedHeaderRecords = globalUnknownRecords.merging(localUnknownRecords) { $1 }
            } else {
                unknownExtendedHeaderRecords = localUnknownRecords
            }
        } else {
            unknownExtendedHeaderRecords = global?.unknownRecords
        }
    }

}
