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

    private let dataObject: Data

    init(_ entryInfo: SevenZipEntryInfo, _ data: Data) {
        // TODO: Make data decoding here?
        self.info = entryInfo
        self.dataObject = data
        self.entryAttributes = [:]
    }

    public func data() -> Data {
        return dataObject
    }

}
