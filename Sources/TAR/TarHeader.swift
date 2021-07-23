// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// This type represents the low-level header structure of the TAR format.
struct TarHeader {

    enum HeaderEntryType {
        case normal(ContainerEntryType)
        case special(SpecialEntryType)
    }

    enum SpecialEntryType: UInt8 {
        case longName = 76
        case longLinkName = 75
        case globalExtendedHeader = 103
        case localExtendedHeader = 120
        // Sun were the first to use extended headers. Their headers are mostly compatible with PAX ones, but differ in
        // the typeflag used ("X" instead of "x").
        case sunExtendedHeader = 88
    }

    let name: String
    private(set) var prefix: String?
    let size: Int
    let type: HeaderEntryType
    private(set) var atime: Date?
    private(set) var ctime: Date?
    private(set) var mtime: Date?
    let permissions: Permissions?
    let uid: Int?
    let gid: Int?
    private(set) var uname: String?
    private(set) var gname: String?
    private(set) var deviceMajorNumber: Int?
    private(set) var deviceMinorNumber: Int?
    let linkName: String

    let format: TarContainer.Format
    let blockStartIndex: Int

    init(_ reader: LittleEndianByteReader) throws {
        self.blockStartIndex = reader.offset
        self.name = reader.tarCString(maxLength: 100)

        if let posixAttributes = reader.tarInt(maxLength: 8) {
            // Sometimes file mode field also contains unix type, so we need to filter it out.
            self.permissions = Permissions(rawValue: UInt32(truncatingIfNeeded: posixAttributes) & 0xFFF)
        } else {
            self.permissions = nil
        }

        self.uid = reader.tarInt(maxLength: 8)
        self.gid = reader.tarInt(maxLength: 8)

        guard let size = reader.tarInt(maxLength: 12)
            else { throw TarError.wrongField }
        self.size = size

        if let mtime = reader.tarInt(maxLength: 12) {
            self.mtime = Date(timeIntervalSince1970: TimeInterval(mtime))
        }

        // Checksum
        guard let checksum = reader.tarInt(maxLength: 8)
            else { throw TarError.wrongHeaderChecksum }

        let currentIndex = reader.offset
        reader.offset = blockStartIndex
        var headerBytesForChecksum = reader.bytes(count: 512)
        headerBytesForChecksum.replaceSubrange(148..<156, with: Array(repeating: 0x20, count: 8))
        reader.offset = currentIndex

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, equality in one of them will pass the checksum test.
        let unsignedOurChecksum = headerBytesForChecksum.reduce(0 as UInt) { $0 + UInt(truncatingIfNeeded: $1) }
        let signedOurChecksum = headerBytesForChecksum.reduce(0 as Int) { $0 + $1.toInt() }
        guard unsignedOurChecksum == UInt(truncatingIfNeeded: checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        let fileTypeIndicator = reader.byte()
        if let specialEntryType = SpecialEntryType(rawValue: fileTypeIndicator) {
            self.type = .special(specialEntryType)
        } else {
            self.type = .normal(ContainerEntryType(fileTypeIndicator))
        }

        self.linkName = reader.tarCString(maxLength: 100)

        // There are two different formats utilizing this section of TAR header: GNU format and POSIX (aka "ustar";
        // PAX containers can also be considered as POSIX). They differ in the value of magic field as well as what
        // comes after deviceMinorNumber field. While "ustar" format may contain prefix for file name, GNU format
        // uses this place for storing atime/ctime and fields related to sparse-files. In practice, these fields are
        // rarely used by GNU tar and only present if "incremental backups" options were used. Thus, GNU format TAR
        // container can often be incorrectly considered as having prefix field containing only NULLs.
        let magic = reader.uint64()

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            self.uname = reader.tarCString(maxLength: 32)
            self.gname = reader.tarCString(maxLength: 32)
            self.deviceMajorNumber = reader.tarInt(maxLength: 8)
            self.deviceMinorNumber = reader.tarInt(maxLength: 8)

            if magic == 0x00_20_20_72_61_74_73_75 { // GNU format.
                // GNU format is mostly identical to POSIX format and in the common situations can be considered as
                // having prefix containing only NULLs. However, in the case of incremental backups produced by GNU tar
                // this part of the TAR header is used for storing a lot of different properties. For now, we are only
                // reading atime and ctime.
                if let atime = reader.tarInt(maxLength: 12) {
                    self.atime = Date(timeIntervalSince1970: TimeInterval(atime))
                }
                if let ctime = reader.tarInt(maxLength: 12) {
                    self.ctime = Date(timeIntervalSince1970: TimeInterval(ctime))
                }
                self.format = .gnu
            } else {
                self.prefix = reader.tarCString(maxLength: 155)
                self.format = .ustar
            }
        } else {
            self.format = .prePosix
        }
    }

    init(specialName: String, specialType: SpecialEntryType, size: Int, uid: Int?, gid: Int?) {
        self.name = specialName
        self.type = .special(specialType)
        self.size = size
        self.permissions = Permissions(rawValue: 420)
        self.uid = uid
        self.gid = gid
        self.mtime = Date()
        self.linkName = ""
        if specialType == .longName || specialType == .longLinkName {
            self.format = .gnu
        } else if specialType == .globalExtendedHeader || specialType == .localExtendedHeader {
            self.format = .pax
        } else {
            self.format = .prePosix
        }
        // Unused if header was created using this initializer.
        self.blockStartIndex = -1
    }

    init(_ info: TarEntryInfo) {
        self.name = info.name
        self.type = .normal(info.type)
        self.size = info.size ?? 0 // TODO: tarInt(...) may not work as expected for 0 instead of nil.
        self.atime = info.accessTime
        self.ctime = info.creationTime
        self.mtime = info.modificationTime
        self.permissions = info.permissions
        self.uid = info.ownerID
        self.gid = info.groupID
        self.uname = info.ownerUserName
        self.gname = info.ownerGroupName
        self.deviceMajorNumber = info.deviceMajorNumber
        self.deviceMinorNumber = info.deviceMinorNumber
        self.linkName = info.linkName
        self.format = .pax // TODO: If TarEntryInfo.format is not removed than this should be `info.format`.
        // Unused if header was created using this initializer.
        self.blockStartIndex = -1
    }

}
