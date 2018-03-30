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
    private(set) var extendedTimestampExtraField: ExtendedTimestampExtraField?

    /// 0x000a extra field.
    private(set) var ntfsExtraField: NtfsExtraField?

    // 0x7855 extra field doesn't have any information in Central Directory.

    /// 0x7875 extra field.
    private(set) var infoZipNewUnixExtraField: InfoZipNewUnixExtraField?

    let customExtraFields: [ZipExtraField]

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
        var customExtraFields = [ZipExtraField]()
        while byteReader.offset - extraFieldStart < extraFieldLength {
            // There are a lot of possible extra fields.
            let headerID = byteReader.uint16()
            let size = byteReader.uint16().toInt()
            switch headerID {
            case 0x0001: // Zip64
                // Zip64 extra field is a special case, because it requires knowledge about central directory fields.
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
                self.extendedTimestampExtraField = ExtendedTimestampExtraField(byteReader, size,
                                                                               location: .centralDirectory)
            case 0x000a: // NTFS Extra Fields
                self.ntfsExtraField = NtfsExtraField(byteReader, size, location: .centralDirectory)
            case 0x7855: // Info-ZIP Unix Extra Field
                // If there is any data for Info-ZIP Unix extra field in central directory (`size != 0`), skip it.
                // However, according to definition of this extra field it shouldn't have any data in CD.
                byteReader.offset += size
            case 0x7875: // Info-ZIP New Unix Extra Field
                self.infoZipNewUnixExtraField = InfoZipNewUnixExtraField(byteReader, size, location: .centralDirectory)
            default:
                let customFieldOffset = byteReader.offset
                if let customExtraFieldType = ZipContainer.customExtraFields[headerID],
                    customExtraFieldType.id == headerID,
                    let customExtraField = customExtraFieldType.init(byteReader, size, location: .centralDirectory),
                    customExtraField.id == headerID {
                    customExtraFields.append(customExtraField)
                    guard byteReader.offset == customFieldOffset + size
                        else { fatalError("Custom field in Central Directory with ID=\(headerID) of" +
                            "type=\(customExtraFieldType) failed to read exactly \(size) bytes.") }
                } else {
                    byteReader.offset = customFieldOffset + size
                }
            }
        }
        self.customExtraFields = customExtraFields

        guard let fileComment = byteReader.getZipStringField(fileCommentLength, useUtf8)
            else { throw ZipError.wrongTextField }
        self.fileComment = fileComment

        self.nextEntryOffset = byteReader.offset
    }

}
