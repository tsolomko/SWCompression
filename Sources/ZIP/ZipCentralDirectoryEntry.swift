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

    private(set) var localHeaderOffset: UInt64

    private(set) var modificationTimestamp: UInt32?

    private(set) var ntfsMtime: UInt64?
    private(set) var ntfsAtime: UInt64?
    private(set) var ntfsCtime: UInt64?

    let nextEntryIndex: Int

    // We don't use `DataWithPointer` as argument, because it doesn't work well in asynchronous environment.
    init(_ data: Data, _ offset: Int) throws {
        let pointerData = ByteReader(data: data)
        pointerData.index = offset

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

        self.compSize = UInt64(truncatingIfNeeded: pointerData.uint32())
        self.uncompSize = UInt64(truncatingIfNeeded: pointerData.uint32())

        let fileNameLength = pointerData.uint16().toInt()
        let extraFieldLength = pointerData.uint16().toInt()
        let fileCommentLength = pointerData.uint16().toInt()

        self.diskNumberStart = UInt32(truncatingIfNeeded: pointerData.uint16())

        self.internalFileAttributes = pointerData.uint16()
        self.externalFileAttributes = pointerData.uint32()

        self.localHeaderOffset = UInt64(truncatingIfNeeded: pointerData.uint32())

        guard let fileName = pointerData.getZipStringField(fileNameLength, useUtf8)
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
                if self.localHeaderOffset == 0xFFFFFFFF {
                    self.localHeaderOffset = pointerData.uint64()
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
                    if tag == 0x0001 {
                        self.ntfsMtime = pointerData.uint64()
                        self.ntfsAtime = pointerData.uint64()
                        self.ntfsCtime = pointerData.uint64()
                    }
                }
            default:
                pointerData.index += size
            }
        }

        guard let fileComment = pointerData.getZipStringField(fileCommentLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileComment = fileComment

        self.nextEntryIndex = pointerData.index
    }

}
