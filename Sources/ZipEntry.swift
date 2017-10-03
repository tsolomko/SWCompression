// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents either a file or directory entry in ZIP container.
public class ZipEntry: ContainerEntry {

    private let cdEntry: ZipCentralDirectoryEntry
    private var localHeader: ZipLocalHeader?
    private let containerData: Data

    /// Name of the file or directory.
    public var name: String {
        return self.cdEntry.fileName
    }

    /// Comment associated with the entry.
    public var comment: String? {
        return self.cdEntry.fileComment
    }

    /// File or directory attributes related to the file system of the container's creator.
    public var attributes: UInt32 {
        return self.cdEntry.externalFileAttributes
    }

    /// Size of the data associated with the entry.
    public var size: Int {
        return Int(truncatingBitPattern: cdEntry.uncompSize)
    }

    /**
     True, if entry is a directory.
     For MS-DOS and UNIX-like container creator's OS, the result is based on 'external file attributes'.
     Otherwise, it is true if size of data is 0 AND last character of entry's name is '/'.
     */
    public var isDirectory: Bool {
        if let fileType = entryAttributes[FileAttributeKey.type] as? FileAttributeType {
            return fileType == FileAttributeType.typeDirectory
        } else {
            return size == 0 && name.characters.last == "/"
        }
    }

    /// True, if entry is a symbolic link.
    public let isLink: Bool

    /// Path to a linked file for symbolic link entry.
    public lazy var linkPath: String? = {
        guard self.isLink, let entryData = try? self.data()
            else { return nil }
        return String(data: entryData, encoding: .utf8)
    }()

    /// True if entry is likely to be text or ASCII file.
    public var isTextFile: Bool {
        return cdEntry.internalFileAttributes & 0x1 != 0
    }

    /**
     Provides a dictionary with various attributes of the entry.
     `FileAttributeKey` values are used as dictionary keys.

     ## Possible attributes:

     - `FileAttributeKey.modificationDate`
     - `FileAttributeKey.size`
     - `FileAttributeKey.type`, only if origin OS was UNIX- or DOS-like.
     - `FileAttributeKey.posixPermissions`, only if origin OS was UNIX-like.
     - `FileAttributeKey.appendOnly`, only if origin OS was DOS-like.
     */
    public let entryAttributes: [FileAttributeKey: Any]

    /**
     Returns data associated with this entry.

     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of the problem. An error can indicate that container is damaged.
     */
    public func data() throws -> Data {
        // Now, let's move to the location of local header.
        let pointerData = DataWithPointer(data: self.containerData)
        pointerData.index = Int(UInt32(truncatingBitPattern: self.cdEntry.offset))

        if localHeader == nil {
            localHeader = try ZipLocalHeader(pointerData)
            // Check local header for consistency with Central Directory entry.
            guard localHeader!.generalPurposeBitFlags == cdEntry.generalPurposeBitFlags &&
                localHeader!.compressionMethod == cdEntry.compressionMethod &&
                localHeader!.lastModFileTime == cdEntry.lastModFileTime &&
                localHeader!.lastModFileDate == cdEntry.lastModFileDate
                else { throw ZipError.wrongLocalHeader }
        } else {
            pointerData.index += localHeader!.headerSize
        }

        let hasDataDescriptor = localHeader!.generalPurposeBitFlags & 0x08 != 0

        // If file has data descriptor, then some values in local header are absent.
        // So we need to use values from CD entry.
        var uncompSize = hasDataDescriptor ?
            Int(UInt32(truncatingBitPattern: cdEntry.uncompSize)) :
            Int(UInt32(truncatingBitPattern: localHeader!.uncompSize))
        var compSize = hasDataDescriptor ?
            Int(UInt32(truncatingBitPattern: cdEntry.compSize)) :
            Int(UInt32(truncatingBitPattern: localHeader!.compSize))
        var crc32 = hasDataDescriptor ? cdEntry.crc32 : localHeader!.crc32

        let fileBytes: [UInt8]
        let fileDataStart = pointerData.index
        switch localHeader!.compressionMethod {
        case 0:
            fileBytes = pointerData.bytes(count: uncompSize)
        case 8:
            let bitReader = BitReader(data: pointerData.data, bitOrder: .reversed)
            bitReader.index = pointerData.index
            fileBytes = try Deflate.decompress(bitReader)
            // Sometimes pointerData stays in not-aligned state after deflate decompression.
            // Following line ensures that this is not the case.
            bitReader.align()
            pointerData.index = bitReader.index
        case 12:
            #if (!SWCOMPRESSION_POD_ZIP) || (SWCOMPRESSION_POD_ZIP && SWCOMPRESSION_POD_BZ2)
                // BZip2 algorithm considers bits in a byte in a different order.
                let bitReader = BitReader(data: pointerData.data, bitOrder: .straight)
                bitReader.index = pointerData.index
                fileBytes = try BZip2.decompress(bitReader)
                bitReader.align()
                pointerData.index = bitReader.index
            #else
                throw ZipError.compressionNotSupported
            #endif
        case 14:
            #if (!SWCOMPRESSION_POD_ZIP) || (SWCOMPRESSION_POD_ZIP && SWCOMPRESSION_POD_LZMA)
                pointerData.index += 4 // Skipping LZMA SDK version and size of properties.
                let lzmaDecoder = try LZMADecoder(pointerData)
                try lzmaDecoder.decodeLZMA(uncompSize)
                fileBytes = lzmaDecoder.out
            #else
                throw ZipError.compressionNotSupported
            #endif
        default:
            throw ZipError.compressionNotSupported
        }
        let realCompSize = pointerData.index - fileDataStart

        if hasDataDescriptor {
            // Now we need to parse data descriptor itself.
            // First, it might or might not have signature.
            let ddSignature = pointerData.uint32()
            if ddSignature != 0x08074b50 {
                pointerData.index -= 4
            }
            // Now, let's update from CD with values from data descriptor.
            crc32 = pointerData.uint32()
            let sizeOfSizeField: UInt64 = localHeader!.zip64FieldsArePresent ? 8 : 4
            compSize = Int(pointerData.uint64(count: sizeOfSizeField))
            uncompSize = Int(pointerData.uint64(count: sizeOfSizeField))
        }

        guard compSize == realCompSize && uncompSize == fileBytes.count
            else { throw ZipError.wrongSize }
        guard crc32 == UInt32(CheckSums.crc32(fileBytes))
            else { throw ZipError.wrongCRC32(Data(bytes: fileBytes)) }

        return Data(bytes: fileBytes)
    }

    init(_ cdEntry: ZipCentralDirectoryEntry, _ pointerData: DataWithPointer) {
        self.cdEntry = cdEntry
        self.containerData = pointerData.data

        var attributesDict = [FileAttributeKey: Any]()

        // Modification time
        let dosDate = cdEntry.lastModFileDate.toInt()

        let day = dosDate & 0x1F
        let month = (dosDate & 0x1E0) >> 5
        let year = 1980 + ((dosDate & 0xFE00) >> 9)

        let dosTime = cdEntry.lastModFileTime.toInt()

        let seconds = 2 * (dosTime & 0x1F)
        let minutes = (dosTime & 0x7E0) >> 5
        let hours = (dosTime & 0xF800) >> 11

        if let mtime = DateComponents(calendar: Calendar(identifier: .iso8601),
                                      timeZone: TimeZone(abbreviation: "UTC"),
                                      year: year, month: month, day: day,
                                      hour: hours, minute: minutes, second: seconds).date {
            attributesDict[FileAttributeKey.modificationDate] = mtime
        }

        // Extended Timestamp
        if let mtimestamp = cdEntry.modificationTimestamp {
            attributesDict[FileAttributeKey.modificationDate] = Date(timeIntervalSince1970: TimeInterval(mtimestamp))
        }

        // NTFS Extra Fields
        if let mtime = Date(from: cdEntry.ntfsMtime) {
            attributesDict[FileAttributeKey.modificationDate] = mtime
        }
        if let ctime = Date(from: cdEntry.ntfsCtime) {
            attributesDict[FileAttributeKey.creationDate] = ctime
        }

        // Size
        attributesDict[FileAttributeKey.size] = cdEntry.uncompSize

        // External file attributes.

        // For unix-like origin systems we can parse extended attributes.
        let hostSystem = (cdEntry.versionMadeBy & 0xFF00) >> 8
        if hostSystem == 3 {
            // File type.
            let fileType = (cdEntry.externalFileAttributes & 0xF0000000) >> 28
            switch fileType {
            case 0x2:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeCharacterSpecial
            case 0x4:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
            case 0x6:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeBlockSpecial
            case 0x8:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
            case 0xA:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeSymbolicLink
            case 0xC:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeSocket
            default:
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeUnknown
            }

            // Posix permissions.
            let posixPermissions = (cdEntry.externalFileAttributes & 0x0FFF0000) >> 16
            attributesDict[FileAttributeKey.posixPermissions] = posixPermissions
        }

        // For dos and unix-like systems we can parse dos attributes.
        if hostSystem == 0 || hostSystem == 3 {
            let dosAttributes = cdEntry.externalFileAttributes & 0xFF

            if dosAttributes & 0x10 != 0 && hostSystem == 0 {
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeDirectory
            } else if hostSystem == 0 {
                attributesDict[FileAttributeKey.type] = FileAttributeType.typeRegular
            }

            if dosAttributes & 0x1 != 0 {
                attributesDict[FileAttributeKey.appendOnly] = true
            }
        }

        self.entryAttributes = attributesDict
        self.isLink = attributesDict[FileAttributeKey.type] as? FileAttributeType == FileAttributeType.typeSymbolicLink
    }

}
