// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry in 7-Zip container.
public class SevenZipEntry: ContainerEntry {

    /// Various information about entry.
    public let info: SevenZipEntryInfo

    /// Entry's name.
    public var name: String {
        return info.name ?? ""
    }

    /// Entry's data size.
    public var size: Int {
        return info.size ?? 0
    }

    /// True, if entry is a directory.
    public var isDirectory: Bool {
        return info.isDirectory
    }

    /// True, if entry is a symbolic link.
    public let isLink: Bool

    /// Path to a linked file for symbolic link entry.
    public let linkPath: String?

    /**
     Provides a dictionary with various attributes of the entry.
     `FileAttributeKey` values are used as dictionary keys.

     ## Possible attributes:

     - `FileAttributeKey.posixPermissions`,
     - `FileAttributeKey.size`,
     - `FileAttributeKey.modificationDate`,
     - `FileAttributeKey.creationDate`,
     - `FileAttributeKey.type`,
     - `FileAttributeKey.appendOnly`.

     Most modern TAR containers are in UStar format.
     */
    public var entryAttributes: [FileAttributeKey: Any]

    /**
     True, if data for entry is available. 
     It might not be depending on the content of the container.
     */
    public let dataIsAvailable: Bool

    private let dataObject: Data?

    init(_ entryInfo: SevenZipEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.dataObject = data
        self.dataIsAvailable = data != nil

        var attributesDict = [FileAttributeKey: Any]()

        if let mtime = entryInfo.modificationTime {
            attributesDict[FileAttributeKey.modificationDate] = mtime
        }

        if let ctime = entryInfo.creationTime {
            attributesDict[FileAttributeKey.creationDate] = ctime
        }

        if let size = entryInfo.size {
            attributesDict[FileAttributeKey.size] = size
        }

        if let permissions = entryInfo.permissions {
            attributesDict[FileAttributeKey.posixPermissions] = permissions.rawValue
        }

        if let unixType = entryInfo.unixType {
            switch unixType {
            case .characterSpecial:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeCharacterSpecial
            case .directory:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
            case .blockSpecial:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeBlockSpecial
            case .regular:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
            case .symbolicLink:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeSymbolicLink
            case .socket:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeSocket
            default:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeUnknown
            }
        }

        if let dosAttrbutes = entryInfo.dosAttributes {
            if dosAttrbutes.contains(.readOnly) {
                attributesDict[FileAttributeKey.appendOnly] = true
            }

            if dosAttrbutes.contains(.directory) && attributesDict[FileAttributeKey.type] == nil {
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
            }
        }

        if entryInfo.isDirectory && attributesDict[FileAttributeKey.type] == nil {
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
        } else if attributesDict[FileAttributeKey.type] == nil {
            // We still need some type for an entry.
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
        }

        if attributesDict[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeSymbolicLink {
            self.isLink = true
            if let data = data {
                self.linkPath = String(data: data, encoding: .utf8)
            } else {
                self.linkPath = nil
            }
        } else {
            self.isLink = false
            self.linkPath = nil
        }

        self.entryAttributes = attributesDict
    }

    /**
     Returns data associated with this entry.
     
     - Throws: `SevenZipError.dataIsUnavailable` if data for entry isn't available.
     */
    public func data() throws -> Data {
        if let data = dataObject {
            return data
        } else {
            throw SevenZipError.dataIsUnavailable
        }
    }

}
