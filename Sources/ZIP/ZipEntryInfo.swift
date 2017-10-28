// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public struct ZipEntryInfo: ContainerEntryInfo {

    let cdEntry: ZipCentralDirectoryEntry
    let localHeader: ZipLocalHeader

    // MARK: ContainerEntryInfo
    
    /// Name of the file or directory.
    public let name: String?

    /// Size of the data associated with the entry.
    public let size: Int?

    public let type: ContainerEntryType

    // TODO: Describe preference of various fields when setting time properties.
    public let accessTime: Date?

    public let creationTime: Date?

    public let modificationTime: Date?

    public let permissions: Permissions?

    // MARK: ZIP specific

    public let comment: String

    public let externalFileAttributes: UInt32

    public let dosAttributes: DosAttributes?

    /// True, if entry is likely to be text or ASCII file.
    public let isTextFile: Bool

    public let fileSystemType: FileSystemType?

    // We don't use `DataWithPointer` as argument, because it doesn't work well in asynchronous environment.
    init(_ data: Data, _ offset: Int, _ currentDiskNumber: UInt32) throws {
        // Load and save Central Directory entry and Local Header.
        let cdEntry = try ZipCentralDirectoryEntry(data, offset)
        self.cdEntry = cdEntry
        
        let localHeader = try ZipLocalHeader(data, Int(truncatingIfNeeded: cdEntry.localHeaderOffset))
        try localHeader.validate(with: cdEntry, currentDiskNumber)
        self.localHeader = localHeader

        // Name.
        self.name = cdEntry.fileName

        // Set Modification Time.
        if let mtimestamp = cdEntry.modificationTimestamp {
            // Extended Timestamp extra field.
            self.modificationTime = Date(timeIntervalSince1970: TimeInterval(mtimestamp))
        } else if let mtime = Date(cdEntry.ntfsMtime) {
            // NTFS extra field.
            self.modificationTime = mtime
        } else {
            // Native ZIP modification time.
            let dosDate = cdEntry.lastModFileDate.toInt()

            let day = dosDate & 0x1F
            let month = (dosDate & 0x1E0) >> 5
            let year = 1980 + ((dosDate & 0xFE00) >> 9)

            let dosTime = cdEntry.lastModFileTime.toInt()

            let seconds = 2 * (dosTime & 0x1F)
            let minutes = (dosTime & 0x7E0) >> 5
            let hours = (dosTime & 0xF800) >> 11

            self.modificationTime = DateComponents(calendar: Calendar(identifier: .iso8601),
                                                   timeZone: TimeZone(abbreviation: "UTC"),
                                                   year: year, month: month, day: day,
                                                   hour: hours, minute: minutes, second: seconds).date
        }

        // Set Creation Time.
        if let ctimestamp = localHeader.creationTimestamp {
            // Extended Timestamp extra field.
            self.creationTime = Date(timeIntervalSince1970: TimeInterval(ctimestamp))
        } else if let ctime = Date(cdEntry.ntfsCtime) {
            // NTFS extra field.
            self.creationTime = ctime
        } else {
            self.creationTime = nil
        }

        // Set Creation Time.
        if let atimestamp = localHeader.accessTimestamp {
            // Extended Timestamp extra field.
            self.accessTime = Date(timeIntervalSince1970: TimeInterval(atimestamp))
        } else if let atime = Date(cdEntry.ntfsAtime) {
            // NTFS extra field.
            self.accessTime = atime
        } else {
            self.accessTime = nil
        }

        // Size
        self.size = Int(cdEntry.uncompSize)

        // External file attributes.
        self.externalFileAttributes = cdEntry.externalFileAttributes
        self.permissions = Permissions(rawValue: (0x0FFF0000 & cdEntry.externalFileAttributes) >> 16)
        self.dosAttributes = DosAttributes(rawValue: 0xFF & cdEntry.externalFileAttributes)

        // Set entry type.
        if let unixType = ContainerEntryType((0xF0000000 & cdEntry.externalFileAttributes) >> 16) {
            self.type = unixType
        } else if let dosAttributes = self.dosAttributes {
            if dosAttributes.contains(.directory) {
                self.type = .directory
            } else {
                self.type = .regular
            }
        } else if size == 0 && cdEntry.fileName.last == "/" {
            self.type = .directory
        } else {
            self.type = .regular
        }

        // File comment.
        self.comment = cdEntry.fileComment

        // Is text file?
        self.isTextFile = cdEntry.internalFileAttributes & 0x1 != 0

        // File system type of machine where this container was created.
        self.fileSystemType = FileSystemType(cdEntry.versionMadeBy)
    }

}
