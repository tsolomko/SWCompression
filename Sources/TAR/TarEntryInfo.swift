// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides access to information about an entry from the TAR container.
public struct TarEntryInfo: ContainerEntryInfo {

    enum SpecialEntryType: UInt8 {
        case longName = 76
        case longLinkName = 75
        case globalExtendedHeader = 103
        case localExtendedHeader = 120
    }

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

    /// Entry's compression method. Always `.copy` for entries of TAR containers.
    public let compressionMethod = CompressionMethod.copy

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

    /// All unknown records from global and local PAX extended headers. `nil`, if there were no headers.
    public let unknownExtendedHeaderRecords: [String: String]?

    let specialEntryType: SpecialEntryType?
    let hasRecognizedMagic: Bool

    let blockStartIndex: Int

    init(_ byteReader: ByteReader, _ global: TarExtendedHeader?, _ local: TarExtendedHeader?,
         _ longName: String?, _ longLinkName: String?) throws {
        self.blockStartIndex = byteReader.offset
        var linkName: String
        var name: String

        // File name
        name = try byteReader.nullEndedAsciiString(cutoff: 100)

        // Notes for all the properties processing below:
        // 1. There might be a corresponding field in either global or local extended PAX header.
        // 2. We still need to read general TAR fields so we can't eliminate auxiliary local let-variables.
        // 3. `tarInt` returning `nil` corresponds to either field being unused and filled with NULLs or non-UTF-8
        //    string describing number which means that either this field or container in general is corrupted.
        //    Corruption of the container is should be detected by checksum comparison, so we decided to ignore them
        //    here; the alternative, which was used in previous versions, is to throw an error.

        if let posixAttributes = byteReader.tarInt(maxLength: 8, radix: 8) {
            // Sometimes file mode also contains unix type, so we need to filter it out.
            self.permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixAttributes) & 0xFFF)
        } else {
            self.permissions = nil
        }

        let ownerAccountID = byteReader.tarInt(maxLength: 8)
        self.ownerID = (local?.uid ?? global?.uid) ?? ownerAccountID

        let groupAccountID = byteReader.tarInt(maxLength: 8)
        self.groupID = (local?.gid ?? global?.gid) ?? groupAccountID

        let fileSize = byteReader.tarInt(maxLength: 12, radix: 8)
        self.size = (local?.size ?? global?.size) ?? fileSize

        let mtime = byteReader.tarInt(maxLength: 12, radix: 8)
        if let paxMtime = local?.mtime ?? global?.mtime {
            self.modificationTime = Date(timeIntervalSince1970: paxMtime)
        } else if let mtime = mtime {
            self.modificationTime = Date(timeIntervalSince1970: TimeInterval(mtime))
        } else {
            self.modificationTime = nil
        }

        // Checksum
        guard let checksum = byteReader.tarInt(maxLength: 8, radix: 8)
            else { throw TarError.wrongHeaderChecksum }

        let currentIndex = byteReader.offset
        byteReader.offset = blockStartIndex
        var headerDataForChecksum = byteReader.bytes(count: 512)
        for i in 148..<156 {
            headerDataForChecksum[i] = 0x20
        }
        byteReader.offset = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, equality in one of them will pass the checksum test.
        let unsignedOurChecksumArray = headerDataForChecksum.map { UInt(truncatingIfNeeded: $0) }
        let signedOurChecksumArray = headerDataForChecksum.map { $0.toInt() }

        let unsignedOurChecksum = unsignedOurChecksumArray.reduce(0) { $0 + $1 }
        let signedOurChecksum = signedOurChecksumArray.reduce(0) { $0 + $1 }
        guard unsignedOurChecksum == UInt(truncatingIfNeeded: checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        // File type
        let fileTypeIndicator = byteReader.byte()
        self.specialEntryType = SpecialEntryType(rawValue: fileTypeIndicator)
        self.type = ContainerEntryType(fileTypeIndicator)

        // Linked file name
        linkName = try byteReader.nullEndedAsciiString(cutoff: 100)

        // There are two POSIX-like formats: pre-POSIX used by GNU tools (aka "old-GNU") and POSIX (aka "ustar").
        // They differ in `magic` field value and how other fields are padded (either SPACEs or NULLs).
        // Padding is taken care of in Data extension functions in "ByteReader+Tar.swift" file.
        // Here we deal with magic. First one is "old-GNU", second is "ustar", third is for compatiblity with strange
        // implementations of "ustar", which use SPACEs instead of NULLs.
        let magic = byteReader.uint64()

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            self.hasRecognizedMagic = true
            let uname = try byteReader.nullEndedAsciiString(cutoff: 32)
            self.ownerUserName = (local?.uname ?? global?.uname) ?? uname

            let gname = try byteReader.nullEndedAsciiString(cutoff: 32)
            self.ownerGroupName = (local?.gname ?? global?.gname) ?? gname

            deviceMajorNumber = byteReader.tarInt(maxLength: 8)
            deviceMinorNumber = byteReader.tarInt(maxLength: 8)
            let prefix = try byteReader.nullEndedAsciiString(cutoff: 155)
            if prefix != "" {
                if prefix.last == "/" {
                    name = prefix + name
                } else {
                    name = prefix + "/" + name
                }
            }
        } else {
            self.hasRecognizedMagic = false
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
