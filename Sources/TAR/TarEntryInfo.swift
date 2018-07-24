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
        // Sun were the first to use extended headers. Their headers are mostly compatible with PAX ones, but differ in
        // the typeflag used ("X" instead of "x").
        case sunExtendedHeader = 88
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
    let format: TarContainer.Format

    let blockStartIndex: Int

    init(_ byteReader: ByteReader, _ global: TarExtendedHeader?, _ local: TarExtendedHeader?,
         _ longName: String?, _ longLinkName: String?) throws {
        self.blockStartIndex = byteReader.offset

        // File name
        var name = byteReader.tarCString(maxLength: 100)

        // General notes for all the properties processing below:
        // 1. There might be a corresponding field in either global or local extended PAX header.
        // 2. We still need to read general TAR fields so we can't eliminate auxiliary local let-variables.
        // 3. `tarInt` returning `nil` corresponds to either field being unused and filled with NULLs or non-UTF-8
        //    string describing number which means that either this field or container in general is corrupted.
        //    Corruption of the container should be detected by checksum comparison, so we decided to ignore them here;
        //    the alternative, which was used in previous versions, is to throw an error.

        if let posixAttributes = byteReader.tarInt(maxLength: 8) {
            // Sometimes file mode field also contains unix type, so we need to filter it out.
            self.permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixAttributes) & 0xFFF)
        } else {
            self.permissions = nil
        }

        let ownerAccountID = byteReader.tarInt(maxLength: 8)
        self.ownerID = (local?.uid ?? global?.uid) ?? ownerAccountID

        let groupAccountID = byteReader.tarInt(maxLength: 8)
        self.groupID = (local?.gid ?? global?.gid) ?? groupAccountID

        let fileSize = byteReader.tarInt(maxLength: 12)
        self.size = (local?.size ?? global?.size) ?? fileSize

        let mtime = byteReader.tarInt(maxLength: 12)
        if let paxMtime = local?.mtime ?? global?.mtime {
            self.modificationTime = Date(timeIntervalSince1970: paxMtime)
        } else if let mtime = mtime {
            self.modificationTime = Date(timeIntervalSince1970: TimeInterval(mtime))
        } else {
            self.modificationTime = nil
        }

        // Checksum
        guard let checksum = byteReader.tarInt(maxLength: 8)
            else { throw TarError.wrongHeaderChecksum }

        let currentIndex = byteReader.offset
        byteReader.offset = blockStartIndex
        var headerBytesForChecksum = byteReader.bytes(count: 512)
        headerBytesForChecksum.replaceSubrange(148..<156, with: Array(repeating: 0x20, count: 8))
        byteReader.offset = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, equality in one of them will pass the checksum test.
        let unsignedOurChecksum = headerBytesForChecksum.reduce(0 as UInt) { $0 + UInt(truncatingIfNeeded: $1) }
        let signedOurChecksum = headerBytesForChecksum.reduce(0 as Int) { $0 + $1.toInt() }
        guard unsignedOurChecksum == UInt(truncatingIfNeeded: checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        // File type
        let fileTypeIndicator = byteReader.byte()
        self.specialEntryType = SpecialEntryType(rawValue: fileTypeIndicator)
        self.type = ContainerEntryType(fileTypeIndicator)

        // Linked file name
        let linkName = byteReader.tarCString(maxLength: 100)

        // There are two different formats utilizing this section of TAR header: GNU format and POSIX (aka "ustar";
        // also PAX containers can also be considered POSIX). They differ in the value of magic field as well as what
        // comes after deviceMinorNumber field. While "ustar" format may contain prefix for file name, GNU format
        // uses this place for storing atime/ctime and fields related to sparse-files. In practice, these fields are
        // rarely used by GNU tar and only present if "incremental backups" options were used. Thus, GNU format TAR
        // container can often be incorrectly considered as having prefix field containing only NULLs.
        let magic = byteReader.uint64()

        var gnuAtime: Int?
        var gnuCtime: Int?

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            let uname = byteReader.tarCString(maxLength: 32)
            self.ownerUserName = (local?.uname ?? global?.uname) ?? uname

            let gname = byteReader.tarCString(maxLength: 32)
            self.ownerGroupName = (local?.gname ?? global?.gname) ?? gname

            self.deviceMajorNumber = byteReader.tarInt(maxLength: 8)
            self.deviceMinorNumber = byteReader.tarInt(maxLength: 8)

            if magic == 0x00_20_20_72_61_74_73_75 { // GNU format.
                // GNU format mostly is identical to POSIX format and in the common situations can be considered as
                // having prefix containing only NULLs. However, in the case of incremental backups produced by GNU tar
                // this part of the TAR header is used for storing a lot of different properties. For now, we are only
                // reading atime and ctime.

                gnuAtime = byteReader.tarInt(maxLength: 12)
                gnuCtime = byteReader.tarInt(maxLength: 12)
            } else {
                let prefix = byteReader.tarCString(maxLength: 155)
                if prefix != "" {
                    if prefix.last == "/" {
                        name = prefix + name
                    } else {
                        name = prefix + "/" + name
                    }
                }
            }
        } else {
            self.ownerUserName = local?.uname ?? global?.uname
            self.ownerGroupName = local?.gname ?? global?.gname
            self.deviceMajorNumber = nil
            self.deviceMinorNumber = nil
        }

        if local != nil || global != nil {
            self.format = .pax
        } else if magic == 0x00_20_20_72_61_74_73_75 || longName != nil || longLinkName != nil {
            self.format = .gnu
        } else if magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            self.format = .ustar
        } else {
            self.format = .prePosix
        }

        // Set `name` and `linkName` to values from PAX or GNU format if possible.
        self.name = ((local?.path ?? global?.path) ?? longName) ?? name
        self.linkName = ((local?.linkpath ?? global?.linkpath) ?? longLinkName) ?? linkName

        // Set additional properties from PAX extended headers.
        if let atime = local?.atime ?? global?.atime {
            self.accessTime = Date(timeIntervalSince1970: atime)
        } else if let gnuAtime = gnuAtime {
            self.accessTime = Date(timeIntervalSince1970: TimeInterval(gnuAtime))
        } else {
            self.accessTime = nil
        }

        if let ctime = local?.ctime ?? global?.ctime {
            self.creationTime = Date(timeIntervalSince1970: ctime)
        } else if let gnuCtime = gnuCtime {
            self.creationTime = Date(timeIntervalSince1970: TimeInterval(gnuCtime))
        } else {
            self.creationTime = nil
        }

        self.charset = local?.charset ?? global?.charset
        self.comment = local?.comment ?? global?.comment
        if let localUnknownRecords = local?.unknownRecords {
            if let globalUnknownRecords = global?.unknownRecords {
                self.unknownExtendedHeaderRecords = globalUnknownRecords.merging(localUnknownRecords) { $1 }
            } else {
                self.unknownExtendedHeaderRecords = localUnknownRecords
            }
        } else {
            self.unknownExtendedHeaderRecords = global?.unknownRecords
        }
    }

}
