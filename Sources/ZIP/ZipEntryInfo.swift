// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class ZipEntryInfo: ContainerEntryInfo {

    let cdEntry: ZipCentralDirectoryEntry
    private var localHeader: ZipLocalHeader?
    private let containerData: Data

    // MARK: ContainerEntryInfo
    
    /// Name of the file or directory.
    public var name: String? {
        return self.cdEntry.fileName
    }

    /// Size of the data associated with the entry.
    public var size: Int? {
        return Int(truncatingIfNeeded: cdEntry.uncompSize)
    }

    public let type: ContainerEntryType

    // MARK: TAR specific

    /// Comment associated with the entry.
    public var comment: String? {
        return self.cdEntry.fileComment
    }

    /// File or directory attributes related to the file system of the container's creator.
    public var attributes: UInt32 {
        return self.cdEntry.externalFileAttributes
    }

    /**
     True, if entry is a directory.
     For MS-DOS and UNIX-like container creator's OS, the result is based on 'external file attributes'.
     Otherwise, it is true if size of data is 0 AND last character of entry's name is '/'.
     */
    public var isDirectory: Bool {
        // TODO:
//        if let fileType = entryAttributes[FileAttributeKey.type] as? FileAttributeType {
//            return fileType == FileAttributeType.typeDirectory
//        } else {
//            return size == 0 && name.last == "/"
//        }
        return size == 0 && name!.last == "/"
    }

    /// True, if entry is a symbolic link.
    public let isLink: Bool

    /// Path to a linked file for symbolic link entry.
    public lazy var linkPath: String? = {
        // TODO:
        return nil
//        guard self.isLink, let entryData = try? self.data()
//            else { return nil }
//        return String(data: entryData, encoding: .utf8)
    }()

    /// True if entry is likely to be text or ASCII file.
    public var isTextFile: Bool {
        return cdEntry.internalFileAttributes & 0x1 != 0
    }

    init(_ pointerData: DataWithPointer) throws {
        self.cdEntry = try ZipCentralDirectoryEntry(pointerData)
        self.containerData = pointerData.data

        var attributesDict = [FileAttributeKey: Any]()

        // Modification time
        let dosDate = cdEntry.lastModFileDate.toInt()

        let day = dosDate & 0x1F
        let month = (dosDate & 0x1E0) >> 5
        let year = 1980 + ((dosDate & 0xFE00) >> 9)

        let dosTime = cdEntry.lastModFileTime.toInt()

        let seconds = 2 * (dosTime & 0x1F)
        let minutes = (dosTime & 0x7E0) >> 5
        let hours = (dosTime & 0xF800) >> 11

        if let mtime = DateComponents(calendar: Calendar(identifier: .iso8601),
                                      timeZone: TimeZone(abbreviation: "UTC"),
                                      year: year, month: month, day: day,
                                      hour: hours, minute: minutes, second: seconds).date {
            attributesDict[FileAttributeKey.modificationDate] = mtime
        }

        // Extended Timestamp
        if let mtimestamp = cdEntry.modificationTimestamp {
            attributesDict[FileAttributeKey.modificationDate] = Date(timeIntervalSince1970: TimeInterval(mtimestamp))
        }

        // NTFS Extra Fields
        if let mtime = Date(from: cdEntry.ntfsMtime) {
            attributesDict[FileAttributeKey.modificationDate] = mtime
        }
        if let ctime = Date(from: cdEntry.ntfsCtime) {
            attributesDict[FileAttributeKey.creationDate] = ctime
        }

        // Size
        attributesDict[FileAttributeKey.size] = cdEntry.uncompSize

        // External file attributes.

        // For unix-like origin systems we can parse extended attributes.
        let hostSystem = (cdEntry.versionMadeBy & 0xFF00) >> 8
        if hostSystem == 3 {
            // File type.
            let fileType = (cdEntry.externalFileAttributes & 0xF0000000) >> 28
            switch fileType {
            case 0x2:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeCharacterSpecial
            case 0x4:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
            case 0x6:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeBlockSpecial
            case 0x8:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
            case 0xA:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeSymbolicLink
            case 0xC:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeSocket
            default:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeUnknown
            }

            // Posix permissions.
            let posixPermissions = (cdEntry.externalFileAttributes & 0x0FFF0000) >> 16
            attributesDict[FileAttributeKey.posixPermissions] = posixPermissions
        }

        // For dos and unix-like systems we can parse dos attributes.
        if hostSystem == 0 || hostSystem == 3 {
            let dosAttributes = cdEntry.externalFileAttributes & 0xFF

            if dosAttributes & 0x10 != 0 && hostSystem == 0 {
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
            } else if hostSystem == 0 {
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
            }

            if dosAttributes & 0x1 != 0 {
                attributesDict[FileAttributeKey.appendOnly] = true
            }
        }
        // TODO: attributesDict.
        self.isLink = attributesDict[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeSymbolicLink
        
        self.type = .unknown
    }

}
