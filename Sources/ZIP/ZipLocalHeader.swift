// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

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

    // We don't use `DataWithPointer` as argument, because it doesn't work well in asynchronous environment.
    init(_ data: Data, _ offset: Int) throws {
        let pointerData = DataWithPointer(data: data)
        pointerData.index = offset

        // Check signature.
        guard pointerData.uint32() == 0x04034b50
            else { throw ZipError.wrongSignature }

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
                // In local header both uncompressed size and compressed size fields are required.
                self.uncompSize = pointerData.uint64()
                self.compSize = pointerData.uint64()

                self.zip64FieldsArePresent = true
            case 0x5455: // Extended Timestamp
                let flags = pointerData.byte()
                guard flags & 0xF8 == 0 else { break }
                if flags & 0x01 != 0 {
                    self.modificationTimestamp = pointerData.uint32()
                }
                if flags & 0x02 != 0 {
                    self.accessTimestamp = pointerData.uint32()
                }
                if flags & 0x04 != 0 {
                    self.creationTimestamp = pointerData.uint32()
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

        self.dataOffset = pointerData.index
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
