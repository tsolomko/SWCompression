// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides information about 7-Zip entry.
public struct SevenZipEntryInfo: ContainerEntryInfo {

    /// Represents file access permissions in UNIX format.
    public struct Permissions: OptionSet {

        /// Raw bit flags value (in decimal).
        public let rawValue: UInt32

        /// Initializes permissions with bit flags in decimal.
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Set UID.
        public static let setuid = Permissions(rawValue: 0o4000)

        /// Set GID.
        public static let setgid = Permissions(rawValue: 0o2000)

        /// Sticky bit.
        public static let sticky = Permissions(rawValue: 0o1000)

        /// Owner can read.
        public static let readOwner = Permissions(rawValue: 0o0400)

        /// Owner can write.
        public static let writeOwner = Permissions(rawValue: 0o0200)

        /// Owner can execute.
        public static let executeOwner = Permissions(rawValue: 0o0100)

        /// Group can read.
        public static let readGroup = Permissions(rawValue: 0o0040)

        /// Group can write.
        public static let writeGroup = Permissions(rawValue: 0o0020)

        /// Group can execute.
        public static let executeGroup = Permissions(rawValue: 0o0010)

        /// Others can read.
        public static let readOther = Permissions(rawValue: 0o0004)

        /// Others can write.
        public static let writeOther = Permissions(rawValue: 0o0002)

        /// Others can execute.
        public static let executeOther = Permissions(rawValue: 0o0001)

    }

    /// Represents file attributes in DOS format.
    public struct DosAttributes: OptionSet {

        /// Raw bit flags value.
        public let rawValue: UInt32

        /// Initializes attributes with bit flags.
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// File is archive or archived.
        public static let archive = DosAttributes(rawValue: 0b00100000)

        /// File is a directory.
        public static let directory = DosAttributes(rawValue: 0b00010000)

        /// File is a volume.
        public static let volume = DosAttributes(rawValue: 0b00001000)

        /// File is a system file.
        public static let system = DosAttributes(rawValue: 0b00000100)

        /// File is hidden.
        public static let hidden = DosAttributes(rawValue: 0b00000010)

        /// File is read-only.
        public static let readOnly = DosAttributes(rawValue: 0b00000001)

    }

    /// Represents file type in UNIX format.
    public enum UnixType: UInt32 {
        /// FIFO special file.
        case fifo = 0o010000
        /// Character special file.
        case characterSpecial = 0o020000
        /// Directory.
        case directory = 0o040000
        /// Block special file.
        case blockSpecial = 0o060000
        /// Regular file.
        case regular = 0o100000
        /// Symbolic link.
        case symbolicLink = 0o120000
        /// Socket.
        case socket = 0o140000
    }

    // MARK: ContainerEntryInfo

    /// Entry's name.
    public let name: String?

    /// Entry's data size.
    public let size: Int?

    public let type: ContainerEntryType? = nil

    // MARK: 7-Zip specific

    /// True, if entry is a directory.
    public let isDirectory: Bool

    /// Entry's last access time and date.
    public let accessTime: Date?

    /// Entry's creation time and date.
    public let creationTime: Date?

    /// Entry's last modification time and date.
    public let modificationTime: Date?

    /// 7-Zip internal property which may contain UNIX permissions, type and/or DOS attributes.
    public let winAttributes: UInt32?

    /// Entry's UNIX file access permissions.
    public let permissions: Permissions?

    /// Entry's DOS attributes.
    public let dosAttributes: DosAttributes?

    /// Entry's UNIX file type.
    public let unixType: UnixType?

    /// 7-Zip internal propety. Indicates whether entry has a stream (data) inside container.
    public let hasStream: Bool

    /// True, if entry is an empty file. 7-Zip internal property.
    public let isEmpty: Bool

    /**
     True if entry is an anti-file.
     Used in differential backups to indicate that file should be deleted.
     7-Zip internal property.
     */
    public let isAnti: Bool

    /// CRC32 of entry's data.
    public let crc: UInt32?

    init(_ file: SevenZipFileInfo.File, _ size: Int? = nil, _ crc: UInt32? = nil) {
        self.hasStream = !file.isEmptyStream
        self.isEmpty = file.isEmptyFile
        self.isAnti = file.isAntiFile

        self.name = file.name
        self.isDirectory = file.isEmptyStream && !file.isEmptyFile

        self.accessTime = Date(from: file.aTime)
        self.creationTime = Date(from: file.cTime)
        self.modificationTime = Date(from: file.mTime)

        if let attributes = file.winAttributes {
            self.winAttributes = attributes
            self.permissions = Permissions(rawValue: (0x0FFF0000 & attributes) >> 16)
            self.unixType = UnixType(rawValue: (0xF0000000 & attributes) >> 16)
            self.dosAttributes = DosAttributes(rawValue: 0xFF & attributes)
        } else {
            self.winAttributes = nil
            self.permissions = nil
            self.unixType = nil
            self.dosAttributes = nil
        }

        self.crc = crc
        self.size = size
    }

}
