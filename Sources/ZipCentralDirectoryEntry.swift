// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct ZipCentralDirectoryEntry {

    let versionMadeBy: UInt16
    let versionNeeded: UInt16
    let generalPurposeBitFlags: UInt16
    let compressionMethod: UInt16
    let lastModFileTime: UInt16
    let lastModFileDate: UInt16
    let crc32: UInt32
    private(set) var compSize: UInt64
    private(set) var uncompSize: UInt64

    let fileName: String
    let fileComment: String

    private(set) var diskNumberStart: UInt32

    let internalFileAttributes: UInt16
    let externalFileAttributes: UInt32

    private(set) var offset: UInt64

    private(set) var modificationTimestamp: UInt32?

    private(set) var ntfsMtime: UInt64?
    private(set) var ntfsAtime: UInt64?
    private(set) var ntfsCtime: UInt64?

    init(_ pointerData: DataWithPointer, _ currentDiskNumber: UInt32) throws {
        // Check signature.
        guard pointerData.uint32() == 0x02014b50
            else { throw ZipError.wrongSignature }

        self.versionMadeBy = pointerData.uint16()
        self.versionNeeded = pointerData.uint16()

        self.generalPurposeBitFlags = pointerData.uint16()
        let useUtf8 = generalPurposeBitFlags & 0x800 != 0

        self.compressionMethod = pointerData.uint16()

        self.lastModFileTime = pointerData.uint16()
        self.lastModFileDate = pointerData.uint16()

        self.crc32 = pointerData.uint32()

        self.compSize = pointerData.uint64(count: 4)
        self.uncompSize = pointerData.uint64(count: 4)

        let fileNameLength = pointerData.uint16().toInt()
        let extraFieldLength = pointerData.uint16().toInt()
        let fileCommentLength = pointerData.uint16().toInt()

        self.diskNumberStart = pointerData.uint32(count: 2)

        self.internalFileAttributes = pointerData.uint16()
        self.externalFileAttributes = pointerData.uint32()

        self.offset = pointerData.uint64(count: 4)

        guard let fileName = ZipCommon.getStringField(pointerData, fileNameLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileName = fileName

        let extraFieldStart = pointerData.index
        while pointerData.index - extraFieldStart < extraFieldLength {
            // There are a lot of possible extra fields.
            let headerID = pointerData.uint16()
            let size = pointerData.uint16().toInt()
            switch headerID {
            case 0x0001: // Zip64
                if self.uncompSize == 0xFFFFFFFF {
                    self.uncompSize = pointerData.uint64()
                }
                if self.compSize == 0xFFFFFFFF {
                    self.compSize = pointerData.uint64()
                }
                if self.offset == 0xFFFFFFFF {
                    self.offset = pointerData.uint64()
                }
                if self.diskNumberStart == 0xFFFF {
                    self.diskNumberStart = pointerData.uint32()
                }
            case 0x5455: // Extended Timestamp
                let flags = pointerData.byte()
                guard flags & 0xF8 == 0 else { break }
                if flags & 0x01 != 0 {
                    self.modificationTimestamp = pointerData.uint32()
                }
            case 0x000a: // NTFS Extra Fields
                let ntfsExtraFieldsStartIndex = pointerData.index
                pointerData.index += 4 // Skipping reserved bytes.
                while pointerData.index - ntfsExtraFieldsStartIndex < size {
                    let tag = pointerData.uint16()
                    pointerData.index += 2 // Skipping size of attributes for this tag.
                    switch tag {
                    case 0x0001:
                        self.ntfsMtime = pointerData.uint64()
                        self.ntfsAtime = pointerData.uint64()
                        self.ntfsCtime = pointerData.uint64()
                    default:
                        break
                    }
                }
            default:
                pointerData.index += size
            }
        }

        guard let fileComment = ZipCommon.getStringField(pointerData, fileCommentLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileComment = fileComment

        // Let's check entry's values for consistency.
        guard self.versionNeeded & 0xFF <= 63
            else { throw ZipError.wrongVersion }
        guard self.diskNumberStart == currentDiskNumber
            else { throw ZipError.multiVolumesNotSupported }
        guard self.generalPurposeBitFlags & 0x2000 == 0 &&
            self.generalPurposeBitFlags & 0x40 == 0 &&
            self.generalPurposeBitFlags & 0x01 == 0
            else { throw ZipError.encryptionNotSupported }
        guard self.generalPurposeBitFlags & 0x20 == 0
            else { throw ZipError.patchingNotSupported }
    }

}
