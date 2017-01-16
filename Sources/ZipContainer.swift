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
    case WrongCentralDirectoryHeaderSignature
    case EncryptionNotSupported
    case PatchingNotSupported
    case CompressionNotSupported
    case WrongLocalHeaderSignature
    case WrongLocalHeader
    case WrongCRC32
    case WrongCompressedSize
    case WrongUncompressedSize
}

public class ZipContainer {

    public static func open(containerData data: Data) throws -> [String : Data] {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        // Looking for the end of central directory (CD) record.
        var zip64RecordExists = false

        pointerData.index = pointerData.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            // Check signature.
            if pointerData.uint64FromAlignedBytes(count: 4) == 0x06054b50 {
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

        // There is also a .ZIP file comment, but we don't need it.
        // Here's how it can be processed:
        // let zipComment = String(data: Data(bytes: pointerData.alignedBytes(count: zipCommentLength)),
        //                         encoding: .utf8)

        if zip64RecordExists { // We need to find Zip64 end of CD locator.
            // Back to start of end of CD record.
            pointerData.index -= zipCommentLength + 22
            // Zip64 locator takes exactly 20 bytes.
            pointerData.index -= 20

            // Check signature.
            guard pointerData.uint64FromAlignedBytes(count: 4) == 0x07064b50
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

            // Check signature.
            guard pointerData.uint64FromAlignedBytes(count: 4) == 0x06064b50
                else { throw ZipError.WrongZip64EndCentralDirectorySignature }

            // Following 8 bytes are size of end of zip64 CD, but we don't need it.
            _ = pointerData.uint64FromAlignedBytes(count: 8)

            // Next two bytes are version of compressor, but we don't need it.
            _ = pointerData.uint64FromAlignedBytes(count: 2)
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

            // To find the size of these data:
            // let specialPurposeDataSize = zip64EndCDSize - 56
        }

        // OK, now we are ready to read Central Directory itself.
        pointerData.index = Int(UInt(truncatingBitPattern: cdOffset))

        var result: [String : Data] = [:]
        for _ in 0..<cdEntries {
            // Check signature.
            guard pointerData.uint64FromAlignedBytes(count: 4) == 0x02014b50
                else { throw ZipError.WrongCentralDirectoryHeaderSignature }

            let cdEntry = CentralDirectoryEntry(&pointerData)
            // Let's check entry's values for consistency.
            guard cdEntry.versionNeeded <= 45 // TODO: This value should probably be adjusted according to really supported features.
                else { throw ZipError.WrongVersion }
            guard cdEntry.diskNumberStart == currentDiskNumber
                else { throw ZipError.WrongCentralDirectoryDisk }
            guard cdEntry.generalPurposeBitFlags & 0x2000 == 0 ||
                cdEntry.generalPurposeBitFlags & 0x40 == 0 ||
                cdEntry.generalPurposeBitFlags & 0x01 == 0
                else { throw ZipError.EncryptionNotSupported }
            guard cdEntry.generalPurposeBitFlags & 0x20 == 0
                else { throw ZipError.PatchingNotSupported }
            guard cdEntry.compressionMethod == 8 || cdEntry.compressionMethod == 0
                else { throw ZipError.CompressionNotSupported }

            let currentCDOffset = pointerData.index

            // Now, let's move to the location of local header.
            pointerData.index = Int(UInt32(truncatingBitPattern: cdEntry.offset))

            // Check signature.
            guard pointerData.uint64FromAlignedBytes(count: 4) == 0x04034b50
                else { throw ZipError.WrongLocalHeaderSignature }

            let localHeader = LocalHeader(&pointerData)

            // Check local header for consistency.
            guard localHeader.versionNeeded <= 45 &&
                localHeader.generalPurposeBitFlags == cdEntry.generalPurposeBitFlags &&
                localHeader.compressionMethod == cdEntry.compressionMethod &&
                localHeader.lastModFileTime == cdEntry.lastModFileTime &&
                localHeader.lastModFileDate == cdEntry.lastModFileDate
                else { throw ZipError.WrongLocalHeader }
            let hasDataDescriptor = localHeader.generalPurposeBitFlags & 0x08 != 0

            // If file has data descriptor, then some values in local header are absent.
            // So we need to use values from CD entry.
            var uncompSize = hasDataDescriptor ?
                Int(UInt32(truncatingBitPattern: cdEntry.uncompSize)) :
                Int(UInt32(truncatingBitPattern: localHeader.uncompSize))
            var compSize = hasDataDescriptor ?
                Int(UInt32(truncatingBitPattern: cdEntry.compSize)) :
                Int(UInt32(truncatingBitPattern: localHeader.compSize))
            var crc32 = hasDataDescriptor ? cdEntry.crc32 : localHeader.crc32

            let fileBytes: [UInt8]
            let fileDataStart = pointerData.index
            switch localHeader.compressionMethod {
            case 0:
                fileBytes = pointerData.alignedBytes(count: uncompSize)
            case 8:
                fileBytes = try Deflate.decompress(&pointerData)
                // Sometimes pointerData stays in not-aligned state after deflate decompression.
                // Following line ensures that this is not the case.
                pointerData.skipUntilNextByte()
            default:
                throw ZipError.CompressionNotSupported
            }
            let realCompSize = pointerData.index - fileDataStart

            if hasDataDescriptor {
                // Now we need to parse data descriptor itself.
                // First, it might or might not have signature.
                let ddSignature = pointerData.uint64FromAlignedBytes(count: 4)
                if ddSignature != 0x08074b50 {
                    pointerData.index -= 4
                }
                // Now, let's update from CD with values from data descriptor.
                crc32 = UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 4))
                compSize = Int(UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 4)))
                uncompSize = Int(UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 4)))
            }

            guard compSize == realCompSize
                else { throw ZipError.WrongCompressedSize }
            guard uncompSize == fileBytes.count
                else { throw ZipError.WrongUncompressedSize }
            guard crc32 == UInt32(CheckSums.crc32(fileBytes))
                else { throw ZipError.WrongCRC32 }

            result[localHeader.fileName!] = Data(bytes: fileBytes)

            pointerData.index = currentCDOffset
        }

        return result
    }

}

struct LocalHeader {

    let versionNeeded: Int
    let generalPurposeBitFlags: Int
    let compressionMethod: Int
    let lastModFileTime: Int
    let lastModFileDate: Int

    let crc32: UInt32
    private(set) var compSize: UInt64
    private(set) var uncompSize: UInt64

    let fileName: String?

    init(_ pointerData: inout DataWithPointer) {
        self.versionNeeded = pointerData.intFromAlignedBytes(count: 2)

        self.generalPurposeBitFlags = pointerData.intFromAlignedBytes(count: 2)

        self.compressionMethod = pointerData.intFromAlignedBytes(count: 2)

        self.lastModFileTime = pointerData.intFromAlignedBytes(count: 2)
        self.lastModFileDate = pointerData.intFromAlignedBytes(count: 2)

        self.crc32 = UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 4))

        self.compSize = pointerData.uint64FromAlignedBytes(count: 4)
        self.uncompSize = pointerData.uint64FromAlignedBytes(count: 4)

        let fileNameLength = pointerData.intFromAlignedBytes(count: 2)
        let extraFieldLength = pointerData.intFromAlignedBytes(count: 2)

        self.fileName = String(data: Data(bytes: pointerData.alignedBytes(count: fileNameLength)),
                               encoding: .utf8)

        let extraFieldStart = pointerData.index
        while pointerData.index - extraFieldStart < extraFieldLength {
            // There are a lot of possible extra fields.
            // But we are (currently) only interested in Zip64 related fields (with headerID = 0x0001),
            // because they directly impact further extraction process.
            let headerID = pointerData.intFromAlignedBytes(count: 2)
            let size = pointerData.intFromAlignedBytes(count: 2)
            switch headerID {
            case 0x0001:
                // In local header both uncompressed size and compressed size fields are required.
                self.uncompSize = pointerData.uint64FromAlignedBytes(count: 8)
                self.compSize = pointerData.uint64FromAlignedBytes(count: 8)
            default:
                pointerData.index += size
            }
        }
    }

}

struct CentralDirectoryEntry {

    let versionMadeBy: Int
    let versionNeeded: Int
    let generalPurposeBitFlags: Int
    let compressionMethod: Int
    let lastModFileTime: Int
    let lastModFileDate: Int
    let crc32: UInt32
    private(set) var compSize: UInt64
    private(set) var uncompSize: UInt64

    let fileName: String?
    let fileComment: String?

    private(set) var diskNumberStart: UInt64

    let internalFileAttributes: Int
    let externalFileAttributes: UInt32

    private(set) var offset: UInt64

    init(_ pointerData: inout DataWithPointer) {
        self.versionMadeBy = pointerData.intFromAlignedBytes(count: 2)
        self.versionNeeded = pointerData.intFromAlignedBytes(count: 2)

        self.generalPurposeBitFlags = pointerData.intFromAlignedBytes(count: 2)

        self.compressionMethod = pointerData.intFromAlignedBytes(count: 2)

        self.lastModFileTime = pointerData.intFromAlignedBytes(count: 2)
        self.lastModFileDate = pointerData.intFromAlignedBytes(count: 2)

        self.crc32 = UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 4))

        self.compSize = pointerData.uint64FromAlignedBytes(count: 4)
        self.uncompSize = pointerData.uint64FromAlignedBytes(count: 4)

        let fileNameLength = pointerData.intFromAlignedBytes(count: 2)
        let extraFieldLength = pointerData.intFromAlignedBytes(count: 2)
        let fileCommentLength = pointerData.intFromAlignedBytes(count: 2)

        self.diskNumberStart = pointerData.uint64FromAlignedBytes(count: 2)

        self.internalFileAttributes = pointerData.intFromAlignedBytes(count: 2)
        self.externalFileAttributes = UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 4))

        self.offset = pointerData.uint64FromAlignedBytes(count: 4)

        self.fileName = String(data: Data(bytes: pointerData.alignedBytes(count: fileNameLength)),
                              encoding: .utf8)

        let extraFieldStart = pointerData.index
        while pointerData.index - extraFieldStart < extraFieldLength {
            // There are a lot of possible extra fields.
            // But we are (currently) only interested in Zip64 related fields (with headerID = 0x0001),
            // because they directly impact further extraction process.
            let headerID = pointerData.intFromAlignedBytes(count: 2)
            let size = pointerData.intFromAlignedBytes(count: 2)
            switch headerID {
            case 0x0001:
                if self.uncompSize == 0xFFFFFFFF {
                    self.uncompSize = pointerData.uint64FromAlignedBytes(count: 8)
                }
                if self.compSize == 0xFFFFFFFF {
                    self.compSize = pointerData.uint64FromAlignedBytes(count: 8)
                }
                if self.offset == 0xFFFFFFFF {
                    self.offset = pointerData.uint64FromAlignedBytes(count: 8)
                }
                if self.diskNumberStart == 0xFFFF {
                    self.diskNumberStart = pointerData.uint64FromAlignedBytes(count: 4)
                }
            default:
                pointerData.index += size
            }
        }

        self.fileComment = String(data: Data(bytes: pointerData.alignedBytes(count: fileCommentLength)),
                                 encoding: .utf8)
    }

}
