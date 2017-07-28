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

    init(_ bitReader: BitReader, _ entryInfo: SevenZipEntryInfo) {
        self.info = entryInfo
        self.dataObject = Data()
        self.entryAttributes = [:]
    }

    public func data() -> Data {
        return dataObject
    }
    

}
