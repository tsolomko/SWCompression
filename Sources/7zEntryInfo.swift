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
    public let attributes: UInt32?

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

        if let aTime = SevenZipEntryInfo.ntfsTimeToDate(file.aTime) {
            self.accessTime = aTime
        } else {
            self.accessTime = nil
        }

        if let cTime = SevenZipEntryInfo.ntfsTimeToDate(file.cTime) {
            self.creationTime = cTime
        } else {
            self.creationTime = nil
        }

        if let mTime = SevenZipEntryInfo.ntfsTimeToDate(file.mTime) {
            self.modificationTime = mTime
        } else {
            self.modificationTime = nil
        }

        self.attributes = file.winAttributes

        self.crc = crc
        self.size = size
    }

    private static func ntfsTimeToDate(_ time: UInt64?) -> Date? {
        if let time = time {
            return DateComponents(calendar: Calendar(identifier: .iso8601),
                                  timeZone: TimeZone(abbreviation: "UTC"),
                                  year: 1601, month: 1, day: 1,
                                  hour: 0, minute: 0, second: 0).date?
                .addingTimeInterval(TimeInterval(time) / 10_000_000)
        } else {
            return nil
        }
    }

}
