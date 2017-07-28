// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public struct SevenZipEntryInfo {

    public let name: String?
    public let size: Int?
    public let isDirectory: Bool
    public let accessTime: Date?
    public let creationTime: Date?
    public let modificationTime: Date?
    public let windowsAttributes: Int?

    public let hasStream: Bool
    public let isEmpty: Bool
    public let isAnti: Bool

    public let crc: UInt32?

    init(_ file: SevenZipFileInfo.File, _ size: Int? = nil, _ crc: UInt32? = nil) {
        self.hasStream = !file.isEmptyStream
        self.isEmpty = file.isEmptyFile
        self.isAnti = file.isAntiFile

        self.name = file.name
        self.isDirectory = !file.isEmptyStream || (file.isEmptyStream && file.isAntiFile)

        if let aTime = file.aTime {
            self.accessTime = Date(timeIntervalSince1970: TimeInterval(aTime))
        } else {
            self.accessTime = nil
        }

        if let cTime = file.cTime {
            self.creationTime = Date(timeIntervalSince1970: TimeInterval(cTime))
        } else {
            self.creationTime = nil
        }

        if let mTime = file.mTime {
            self.modificationTime = Date(timeIntervalSince1970: TimeInterval(mTime))
        } else {
            self.modificationTime = nil
        }

        self.windowsAttributes = file.winAttributes

        self.crc = crc
        self.size = size
    }

}
