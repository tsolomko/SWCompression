//
//  ZipContainer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.01.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

public enum ZipError: Error {
    case NotFoundCentralDirectoryEnd
    case WrongCentralDirectoryDisk
    case WrongZip64LocatorSignature
    case WrongZip64EndCentralDirectorySignature
    case WrongVersion
}

public class ZipContainer {

    public static func open(containerData data: Data) throws -> [String: Data] {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        // Looking for the end of central directory (CD) record.
        var zip64RecordExists = false

        pointerData.index = pointerData.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            let signature = pointerData.uint64FromAlignedBytes(count: 4)
            if signature == 0x06054b50 {
                // We found it!
                break
            }
            if pointerData.index == 0 {
                throw ZipError.NotFoundCentralDirectoryEnd
            }
            pointerData.index -= 5
        }

        /// Number of current disk.
        var currentDiskNumber = pointerData.uint64FromAlignedBytes(count: 2)
        /// Number of the disk with the start of CD.
        var cdDiskNumber = pointerData.uint64FromAlignedBytes(count: 2)
        if currentDiskNumber == 0xFFFF || cdDiskNumber == 0xFFFF {
            zip64RecordExists = true
        }
        guard currentDiskNumber == cdDiskNumber
            else { throw ZipError.WrongCentralDirectoryDisk }

        /// Number of CD entries on the current disk.
        var cdEntriesCurrentDisk = pointerData.uint64FromAlignedBytes(count: 2)
        /// Total number of CD entries.
        var cdEntries = pointerData.uint64FromAlignedBytes(count: 2)
        if cdEntriesCurrentDisk == 0xFFFF || cdEntries == 0xFFFF {
            zip64RecordExists = true
        }
        guard cdEntries == cdEntriesCurrentDisk
            else { throw ZipError.WrongCentralDirectoryDisk } // TODO: Probably it should be another error.

        /// Size of Central Directory.
        var cdSize = pointerData.uint64FromAlignedBytes(count: 4)
        /// Offset to the start of Central Directory.
        var cdOffset = pointerData.uint64FromAlignedBytes(count: 4)
        let zipCommentLength = pointerData.intFromAlignedBytes(count: 2)
        if cdSize == 0xFFFFFFFF || cdOffset == 0xFFFFFFFF {
            zip64RecordExists = true
        }

        let zipComment = String(data: data.subdata(in: pointerData.index..<pointerData.index + zipCommentLength),
                                encoding: .utf8)

        if zip64RecordExists { // We need to find Zip64 end of CD locator.
            // Back to start of end of CD record.
            pointerData.index -= zipCommentLength + 22
            // Zip64 locator takes exactly 20 bytes.
            pointerData.index -= 20
            let zip64CDLocatorSignature = pointerData.uint64FromAlignedBytes(count: 4)
            guard zip64CDLocatorSignature == 0x07064b50
                else { throw ZipError.WrongZip64LocatorSignature }
            let zip64CDStartDisk = pointerData.uint64FromAlignedBytes(count: 4)
            guard currentDiskNumber == zip64CDStartDisk
                else { throw ZipError.WrongCentralDirectoryDisk } // TODO: Probably it should be another error.
            let zip64CDEndOffset = pointerData.uint64FromAlignedBytes(count: 8)
            let totalDisks = pointerData.uint64FromAlignedBytes(count: 1)
            guard totalDisks == 1
                else { throw ZipError.WrongCentralDirectoryDisk } // TODO: Probably it should be another error.

            // Now we need to move to Zip64 End of CD.
            pointerData.index = Int(UInt(truncatingBitPattern: zip64CDEndOffset))
            let zip64EndCDSignature = pointerData.uint64FromAlignedBytes(count: 4)
            guard zip64EndCDSignature == 0x06064b50
                else { throw ZipError.WrongZip64EndCentralDirectorySignature }
            let zip64EndCDSize = pointerData.uint64FromAlignedBytes(count: 8)

            let versionMadeBy = pointerData.uint64FromAlignedBytes(count: 2)
            let versionNeeded = pointerData.uint64FromAlignedBytes(count: 2)
            guard versionNeeded <= 45 // TODO: This value should probably be adjusted according to really supported features.
                else { throw ZipError.WrongVersion }

            // Update values read from basic End of CD to the one from Zip64 End of CD.
            currentDiskNumber = pointerData.uint64FromAlignedBytes(count: 4)
            cdDiskNumber = pointerData.uint64FromAlignedBytes(count: 4)
            guard currentDiskNumber == cdDiskNumber
                else { throw ZipError.WrongCentralDirectoryDisk }

            cdEntriesCurrentDisk = pointerData.uint64FromAlignedBytes(count: 8)
            cdEntries = pointerData.uint64FromAlignedBytes(count: 8)
            guard cdEntries == cdEntriesCurrentDisk
                else { throw ZipError.WrongCentralDirectoryDisk } // TODO: Probably it should be another error.

            cdSize = pointerData.uint64FromAlignedBytes(count: 8)
            cdOffset = pointerData.uint64FromAlignedBytes(count: 8)

            // Then, there might be 'zip64 extensible data sector' with 'special purpose data'.
            // But we don't need them currently, so let's skip them.
        }

        return [:]
    }

}
