// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

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

    // 0x5455 extra field.
    private(set) var modificationTimestamp: UInt32?

    // 0x000a extra field.
    private(set) var ntfsMtime: UInt64?
    private(set) var ntfsAtime: UInt64?
    private(set) var ntfsCtime: UInt64?

    // 0x7855 extra field doesn't have any information in Central Directory.

    // 0x7875 extra field.
    private(set) var infoZipNewUid: Int?
    private(set) var infoZipNewGid: Int?

    let nextEntryOffset: Int

    init(_ byteReader: ByteReader) throws {
        // Check signature.
        guard byteReader.uint32() == 0x02014b50
            else { throw ZipError.wrongSignature }

        self.versionMadeBy = byteReader.uint16()
        self.versionNeeded = byteReader.uint16()

        self.generalPurposeBitFlags = byteReader.uint16()
        let useUtf8 = generalPurposeBitFlags & 0x800 != 0

        self.compressionMethod = byteReader.uint16()

        self.lastModFileTime = byteReader.uint16()
        self.lastModFileDate = byteReader.uint16()

        self.crc32 = byteReader.uint32()

        self.compSize = UInt64(truncatingIfNeeded: byteReader.uint32())
        self.uncompSize = UInt64(truncatingIfNeeded: byteReader.uint32())

        let fileNameLength = byteReader.uint16().toInt()
        let extraFieldLength = byteReader.uint16().toInt()
        let fileCommentLength = byteReader.uint16().toInt()

        self.diskNumberStart = UInt32(truncatingIfNeeded: byteReader.uint16())

        self.internalFileAttributes = byteReader.uint16()
        self.externalFileAttributes = byteReader.uint32()

        self.localHeaderOffset = UInt64(truncatingIfNeeded: byteReader.uint32())

        guard let fileName = byteReader.getZipStringField(fileNameLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileName = fileName

        let extraFieldStart = byteReader.offset
        while byteReader.offset - extraFieldStart < extraFieldLength {
            // There are a lot of possible extra fields.
            let headerID = byteReader.uint16()
            let size = byteReader.uint16().toInt()
            switch headerID {
            case 0x0001: // Zip64
                if self.uncompSize == 0xFFFFFFFF {
                    self.uncompSize = byteReader.uint64()
                }
                if self.compSize == 0xFFFFFFFF {
                    self.compSize = byteReader.uint64()
                }
                if self.localHeaderOffset == 0xFFFFFFFF {
                    self.localHeaderOffset = byteReader.uint64()
                }
                if self.diskNumberStart == 0xFFFF {
                    self.diskNumberStart = byteReader.uint32()
                }
            case 0x5455: // Extended Timestamp
                let flags = byteReader.byte()
                guard flags & 0xF8 == 0
                    else { break }
                if flags & 0x01 != 0 {
                    self.modificationTimestamp = byteReader.uint32()
                }
            case 0x000a: // NTFS Extra Fields
                let ntfsExtraFieldsStartIndex = byteReader.offset
                byteReader.offset += 4 // Skipping reserved bytes.
                while byteReader.offset - ntfsExtraFieldsStartIndex < size {
                    let tag = byteReader.uint16()
                    byteReader.offset += 2 // Skipping size of attributes for this tag.
                    if tag == 0x0001 {
                        self.ntfsMtime = byteReader.uint64()
                        self.ntfsAtime = byteReader.uint64()
                        self.ntfsCtime = byteReader.uint64()
                    }
                }
            case 0x7855: // Info-ZIP Unix Extra Field
                break // It doesn't contain any information in Central Directory.
            case 0x7875: // Info-ZIP New Unix Extra Field
                guard byteReader.byte() == 1 // Version must be 1.
                    else { break }
                let uidSize = byteReader.byte().toInt()
                if uidSize > 8 {
                    byteReader.offset += uidSize
                } else {
                    var uid = 0
                    for i in 0..<uidSize {
                        let byte = byteReader.byte()
                        uid |= byte.toInt() << (8 * i)
                    }
                    self.infoZipNewUid = uid
                }

                let gidSize = byteReader.byte().toInt()
                if gidSize > 8 {
                    byteReader.offset += gidSize
                } else {
                    var gid = 0
                    for i in 0..<gidSize {
                        let byte = byteReader.byte()
                        gid |= byte.toInt() << (8 * i)
                    }
                    self.infoZipNewGid = gid
                }
            default:
                byteReader.offset += size
            }
        }

        guard let fileComment = byteReader.getZipStringField(fileCommentLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileComment = fileComment

        self.nextEntryOffset = byteReader.offset
    }

}
