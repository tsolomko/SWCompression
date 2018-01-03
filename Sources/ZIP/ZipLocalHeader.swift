// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

struct ZipLocalHeader {

    let versionNeeded: UInt16
    let generalPurposeBitFlags: UInt16
    let compressionMethod: UInt16
    let lastModFileTime: UInt16
    let lastModFileDate: UInt16

    let crc32: UInt32
    private(set) var compSize: UInt64
    private(set) var uncompSize: UInt64

    private(set) var zip64FieldsArePresent: Bool = false

    let fileName: String

    private(set) var modificationTimestamp: UInt32?
    private(set) var accessTimestamp: UInt32?
    private(set) var creationTimestamp: UInt32?

    private(set) var ntfsMtime: UInt64?
    private(set) var ntfsAtime: UInt64?
    private(set) var ntfsCtime: UInt64?

    let dataOffset: Int

    // TODO:
    // We don't use `ByteReader` as argument, because it doesn't work well in asynchronous environment.
    init(_ data: Data, _ offset: Int) throws {
        let byteReader = ByteReader(data: data)
        byteReader.offset = offset

        // Check signature.
        guard byteReader.uint32() == 0x04034b50
            else { throw ZipError.wrongSignature }

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
                // In local header both uncompressed size and compressed size fields are required.
                self.uncompSize = byteReader.uint64()
                self.compSize = byteReader.uint64()

                self.zip64FieldsArePresent = true
            case 0x5455: // Extended Timestamp
                let flags = byteReader.byte()
                guard flags & 0xF8 == 0 else { break }
                if flags & 0x01 != 0 {
                    self.modificationTimestamp = byteReader.uint32()
                }
                if flags & 0x02 != 0 {
                    self.accessTimestamp = byteReader.uint32()
                }
                if flags & 0x04 != 0 {
                    self.creationTimestamp = byteReader.uint32()
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
            default:
                byteReader.offset += size
            }
        }

        self.dataOffset = byteReader.offset
    }

    func validate(with cdEntry: ZipCentralDirectoryEntry, _ currentDiskNumber: UInt32) throws {
        // Check Local Header for unsupported features.
        guard self.versionNeeded & 0xFF <= 63
            else { throw ZipError.wrongVersion }
        guard self.generalPurposeBitFlags & 0x2000 == 0 &&
            self.generalPurposeBitFlags & 0x40 == 0 &&
            self.generalPurposeBitFlags & 0x01 == 0
            else { throw ZipError.encryptionNotSupported }
        guard self.generalPurposeBitFlags & 0x20 == 0
            else { throw ZipError.patchingNotSupported }

        // Check Central Directory record for unsupported features.
        guard cdEntry.versionNeeded & 0xFF <= 63
            else { throw ZipError.wrongVersion }
        guard cdEntry.diskNumberStart == currentDiskNumber
            else { throw ZipError.multiVolumesNotSupported }

        // Check if Local Header is consistent with Central Directory record.
        guard self.generalPurposeBitFlags == cdEntry.generalPurposeBitFlags &&
            self.compressionMethod == cdEntry.compressionMethod &&
            self.lastModFileTime == cdEntry.lastModFileTime &&
            self.lastModFileDate == cdEntry.lastModFileDate
            else { throw ZipError.wrongLocalHeader }
    }

}
