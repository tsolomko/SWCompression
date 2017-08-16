// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public struct SevenZipEntryInfo {

    public struct Permissions: OptionSet {

        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let setuid = Permissions(rawValue: 0o4000)
        public static let setgid = Permissions(rawValue: 0o2000)
        public static let sticky = Permissions(rawValue: 0o1000)

        public static let readOwner = Permissions(rawValue: 0o0400)
        public static let writeOwner = Permissions(rawValue: 0o0200)
        public static let executeOwner = Permissions(rawValue: 0o0100)

        public static let readGroup = Permissions(rawValue: 0o0040)
        public static let writeGroup = Permissions(rawValue: 0o0020)
        public static let executeGroup = Permissions(rawValue: 0o0010)

        public static let readOther = Permissions(rawValue: 0o0004)
        public static let writeOther = Permissions(rawValue: 0o0002)
        public static let executeOther = Permissions(rawValue: 0o0001)

    }

    public struct DosAttributes: OptionSet {

        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let archive = DosAttributes(rawValue: 0b00100000)
        public static let directory = DosAttributes(rawValue: 0b00010000)
        public static let volume = DosAttributes(rawValue: 0b00001000)
        public static let system = DosAttributes(rawValue: 0b00000100)
        public static let hidden = DosAttributes(rawValue: 0b00000010)
        public static let readOnly = DosAttributes(rawValue: 0b00000001)

    }

    public enum UnixType: UInt32 {
        case fifo = 0o010000
        case characterSpecial = 0o020000
        case directory = 0o040000
        case blockSpecial = 0o060000
        case regular = 0o100000
        case symbolicLink = 0o120000
        case socket = 0o140000
    }

    public let name: String?
    public let size: Int?
    public let isDirectory: Bool
    public let accessTime: Date?
    public let creationTime: Date?
    public let modificationTime: Date?
    public let winAttributes: UInt32?

    public let permissions: Permissions?
    public let dosAttributes: DosAttributes?
    public let unixType: UnixType?

    public let hasStream: Bool
    public let isEmpty: Bool
    public let isAnti: Bool

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
