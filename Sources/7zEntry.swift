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

        if entryInfo.isDirectory {
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
        } else {
            attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
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
