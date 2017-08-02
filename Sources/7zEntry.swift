// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class SevenZipEntry: ContainerEntry {

    public let info: SevenZipEntryInfo

    public var name: String {
        return info.name ?? ""
    }

    public var size: Int {
        return info.size ?? 0
    }

    public var isDirectory: Bool {
        return info.isDirectory
    }

    public let isLink: Bool
    public let linkPath: String?

    public var entryAttributes: [FileAttributeKey: Any]

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

    public func data() throws -> Data {
        if let data = dataObject {
            return data
        } else {
            throw SevenZipError.dataIsUnavailable
        }
    }

}
