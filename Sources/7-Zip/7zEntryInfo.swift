// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides information about 7-Zip entry.
public struct SevenZipEntryInfo: ContainerEntryInfo {

    // MARK: ContainerEntryInfo

    /// Entry's name.
    public let name: String

    /// Entry's data size.
    public let size: Int?

    public let type: ContainerEntryType

    /// Entry's last access time and date.
    public let accessTime: Date?

    /// Entry's creation time and date.
    public let creationTime: Date?

    /// Entry's last modification time and date.
    public let modificationTime: Date?

    /// Entry's UNIX file access permissions.
    public let permissions: Permissions?

    // MARK: 7-Zip specific

    /// 7-Zip internal property which may contain UNIX permissions, type and/or DOS attributes.
    public let winAttributes: UInt32?

    /// Entry's DOS attributes.
    public let dosAttributes: DosAttributes?

    /// True, if entry has a stream (data) inside container. 7-Zip internal propety.
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

        self.accessTime = Date(file.aTime)
        self.creationTime = Date(file.cTime)
        self.modificationTime = Date(file.mTime)

        self.winAttributes = file.winAttributes

        if let attributes = self.winAttributes {
            self.permissions = Permissions(rawValue: (0x0FFF0000 & attributes) >> 16)
            self.dosAttributes = DosAttributes(rawValue: 0xFF & attributes)
        } else {
            self.permissions = nil
            self.dosAttributes = nil
        }

        // Set entry type.
        if let attributes = self.winAttributes,
            let unixType = ContainerEntryType((0xF0000000 & attributes) >> 16) {
            self.type = unixType
        } else if let dosAttributes = self.dosAttributes {
            if dosAttributes.contains(.directory) {
                self.type = .directory
            } else {
                self.type = .regular
            }
        } else if file.isEmptyStream && !file.isEmptyFile {
            self.type = .directory
        } else {
            self.type = .regular
        }

        self.crc = crc
        self.size = size
    }

}
