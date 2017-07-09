// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct ZipLocalHeader {

    let versionNeeded: Int
    let generalPurposeBitFlags: Int
    let compressionMethod: Int
    let lastModFileTime: Int
    let lastModFileDate: Int

    let crc32: UInt32
    private(set) var compSize: UInt64
    private(set) var uncompSize: UInt64

    private(set) var zip64FieldsArePresent: Bool = false

    let fileName: String

    private(set) var modificationTimestamp: Int?
    private(set) var accessTimestamp: Int?
    private(set) var creationTimestamp: Int?

    init(_ pointerData: DataWithPointer) throws {
        // Check signature.
        guard pointerData.uint32() == 0x04034b50
            else { throw ZipError.wrongSignature }

        self.versionNeeded = pointerData.intFromAlignedBytes(count: 2)

        self.generalPurposeBitFlags = pointerData.intFromAlignedBytes(count: 2)

        self.compressionMethod = pointerData.intFromAlignedBytes(count: 2)

        self.lastModFileTime = pointerData.intFromAlignedBytes(count: 2)
        self.lastModFileDate = pointerData.intFromAlignedBytes(count: 2)

        self.crc32 = pointerData.uint32()

        self.compSize = pointerData.uint64(count: 4)
        self.uncompSize = pointerData.uint64(count: 4)

        let fileNameLength = pointerData.intFromAlignedBytes(count: 2)
        let extraFieldLength = pointerData.intFromAlignedBytes(count: 2)

        guard let fileName = String(data: Data(bytes: pointerData.bytes(count: fileNameLength)),
                                    encoding: .utf8)
            else { throw ZipError.wrongTextField }
        self.fileName = fileName

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
                self.uncompSize = pointerData.uint64()
                self.compSize = pointerData.uint64()

                self.zip64FieldsArePresent = true
            case 0x5455: // Extended Timestamp
                let flags = pointerData.byte()
                guard flags & 0xF8 == 0 else { break }
                if flags & 0x01 != 0 {
                    self.modificationTimestamp = pointerData.intFromAlignedBytes(count: 4)
                }
                if flags & 0x02 != 0 {
                    self.accessTimestamp = pointerData.intFromAlignedBytes(count: 4)
                }
                if flags & 0x04 != 0 {
                    self.creationTimestamp = pointerData.intFromAlignedBytes(count: 4)
                }
            default:
                pointerData.index += size
            }
        }

        // Let's check headers's values for consistency.
        guard self.versionNeeded & 0xFF <= 63
            else { throw ZipError.wrongVersion }
        guard self.generalPurposeBitFlags & 0x2000 == 0 &&
            self.generalPurposeBitFlags & 0x40 == 0 &&
            self.generalPurposeBitFlags & 0x01 == 0
            else { throw ZipError.encryptionNotSupported }
        guard self.generalPurposeBitFlags & 0x20 == 0
            else { throw ZipError.patchingNotSupported }
    }

}
