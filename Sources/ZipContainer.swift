//
//  ZipContainer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.01.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Represents an error, which happened during processing ZIP container.
 It may indicate that either container is damaged or it might not be ZIP container at all.
 */
public enum ZipError: Error {
    /// End of Central Directoty record wasn't found.
    case notFoundCentralDirectoryEnd
    /// Wrong signature of one of container's structures.
    case wrongSignature
    /// Wrong either compressed or uncompressed size of a container's entry.
    case wrongSize
    /// Version needed to process container is unsupported.
    case wrongVersion
    /// Container is either spanned or consists of several volumes. These features aren't supported.
    case multiVolumesNotSupported
    /// Entry or record is encrypted. This feature isn't supported.
    case encryptionNotSupported
    /// Entry contains patched data. This feature isn't supported.
    case patchingNotSupported
    /// Entry is compressed using unsupported compression method.
    case compressionNotSupported
    /// Local header of an entry is inconsistent with Central Directory.
    case wrongLocalHeader
    /**
     Computed checksum of entry's data doesn't match the value stored in container.
     Associated value of the error contains entry's data.
     */
    case wrongCRC32(Data)
    /// Either entry's comment or file name cannot be processed using UTF-8 encoding.
    case wrongTextField
}

/// Represents either a file or directory entry in ZIP container.
public class ZipEntry: ContainerEntry {

    private let cdEntry: CentralDirectoryEntry
    private var pointerData: DataWithPointer

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
     True, if an entry is a directory.
     For MS-DOS and UNIX-like container creator's OS, the result is based on 'external file attributes'.
     Otherwise, it is true if size of data is 0 AND last character of entry's name is '/'.
    */
    public var isDirectory: Bool {
        let hostSystem = (cdEntry.versionMadeBy & 0xFF00) >> 8
        if hostSystem == 0 || hostSystem == 3 { // MS-DOS or UNIX case.
            // In both of this cases external file attributes indicate if this is a directory.
            // This is indicated by a special bit in the lowest byte of attributes.
            return cdEntry.externalFileAttributes & 0x10 != 0
        } else {
            return size == 0 && name.characters.last == "/"
        }
    }

    /**
     Returns data associated with this entry.

     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of the problem. An error can indicate that container is damaged.
     */
    public func data() throws -> Data {
        // Now, let's move to the location of local header.
        pointerData.index = Int(UInt32(truncatingBitPattern: self.cdEntry.offset))

        let localHeader = try LocalHeader(&pointerData)

        // Check local header for consistency with Central Directory entry.
        guard localHeader.versionNeeded <= 45 &&
            localHeader.generalPurposeBitFlags == cdEntry.generalPurposeBitFlags &&
            localHeader.compressionMethod == cdEntry.compressionMethod &&
            localHeader.lastModFileTime == cdEntry.lastModFileTime &&
            localHeader.lastModFileDate == cdEntry.lastModFileDate
            else { throw ZipError.wrongLocalHeader }
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
        case 12:
            #if (!SWCOMP_ZIP_POD_BUILD) || (SWCOMP_ZIP_POD_BUILD && SWCOMP_ZIP_POD_BZ2)
                fileBytes = try BZip2.decompress(&pointerData)
            #else
                throw ZipError.compressionNotSupported
            #endif
        case 14:
            #if (!SWCOMP_ZIP_POD_BUILD) || (SWCOMP_ZIP_POD_BUILD && SWCOMP_ZIP_POD_LZMA)
                fileBytes = try LZMA.decompress(&pointerData)
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
            let ddSignature = pointerData.uint32FromAlignedBytes(count: 4)
            if ddSignature != 0x08074b50 {
                pointerData.index -= 4
            }
            // Now, let's update from CD with values from data descriptor.
            crc32 = pointerData.uint32FromAlignedBytes(count: 4)
            let sizeOfSizeField: UInt32 = localHeader.zip64FieldsArePresent ? 8 : 4
            compSize = Int(pointerData.uint32FromAlignedBytes(count: sizeOfSizeField))
            uncompSize = Int(pointerData.uint32FromAlignedBytes(count: sizeOfSizeField))
        }

        guard compSize == realCompSize && uncompSize == fileBytes.count
            else { throw ZipError.wrongSize }
        guard crc32 == UInt32(CheckSums.crc32(fileBytes))
            else { throw ZipError.wrongCRC32(Data(bytes: fileBytes)) }

        return Data(bytes: fileBytes)
    }

    fileprivate init(_ cdEntry: CentralDirectoryEntry, _ pointerData: inout DataWithPointer) {
        self.cdEntry = cdEntry
        self.pointerData = pointerData
    }

}

/// Provides open function for ZIP containers.
public class ZipContainer: Container {

    /**
     Processes ZIP container and returns an array of `ContainerEntries` (which are actually `ZipEntries`).

     - Important: The order of entries is defined by ZIP container and, 
     particularly, by a creator of a given ZIP container.
     It is likely that directories will be encountered earlier than files stored in those directories,
     but one SHOULD NOT rely on any particular order.

     - Parameter container: ZIP container's data.
     
     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of the problem.
     It may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntry` as an array of `ContainerEntry`.
     */
    public static func open(container data: Data) throws -> [ContainerEntry] {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        var entries = [ZipEntry]()

        pointerData.index = pointerData.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            // Check signature.
            if pointerData.uint32FromAlignedBytes(count: 4) == 0x06054b50 {
                // We found it!
                break
            }
            if pointerData.index == 0 {
                throw ZipError.notFoundCentralDirectoryEnd
            }
            pointerData.index -= 5
        }

        let endOfCD = try EndOfCentralDirectory(&pointerData)
        let cdEntries = endOfCD.cdEntries

        // OK, now we are ready to read Central Directory itself.
        pointerData.index = Int(UInt(truncatingBitPattern: endOfCD.cdOffset))

        for _ in 0..<cdEntries {
            let cdEntry = try CentralDirectoryEntry(&pointerData, endOfCD.currentDiskNumber)
            entries.append(ZipEntry(cdEntry, &pointerData))
        }

        return entries
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

    private(set) var zip64FieldsArePresent: Bool = false

    let fileName: String

    init(_ pointerData: inout DataWithPointer) throws {
        // Check signature.
        guard pointerData.uint32FromAlignedBytes(count: 4) == 0x04034b50
            else { throw ZipError.wrongSignature }

        self.versionNeeded = pointerData.intFromAlignedBytes(count: 2)

        self.generalPurposeBitFlags = pointerData.intFromAlignedBytes(count: 2)

        self.compressionMethod = pointerData.intFromAlignedBytes(count: 2)

        self.lastModFileTime = pointerData.intFromAlignedBytes(count: 2)
        self.lastModFileDate = pointerData.intFromAlignedBytes(count: 2)

        self.crc32 = pointerData.uint32FromAlignedBytes(count: 4)

        self.compSize = pointerData.uint64FromAlignedBytes(count: 4)
        self.uncompSize = pointerData.uint64FromAlignedBytes(count: 4)

        let fileNameLength = pointerData.intFromAlignedBytes(count: 2)
        let extraFieldLength = pointerData.intFromAlignedBytes(count: 2)

        guard let fileName = String(data: Data(bytes: pointerData.alignedBytes(count: fileNameLength)),
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
                self.uncompSize = pointerData.uint64FromAlignedBytes(count: 8)
                self.compSize = pointerData.uint64FromAlignedBytes(count: 8)

                self.zip64FieldsArePresent = true
            default:
                pointerData.index += size
            }
        }

        // Let's check headers's values for consistency.
        guard self.versionNeeded <= 45
            else { throw ZipError.wrongVersion }
        guard self.generalPurposeBitFlags & 0x2000 == 0 ||
            self.generalPurposeBitFlags & 0x40 == 0 ||
            self.generalPurposeBitFlags & 0x01 == 0
            else { throw ZipError.encryptionNotSupported }
        guard self.generalPurposeBitFlags & 0x20 == 0
            else { throw ZipError.patchingNotSupported }

        switch self.compressionMethod {
        case 0:
            break
        case 8:
            break
        case 12:
            #if (!SWCOMP_ZIP_POD_BUILD) || (SWCOMP_ZIP_POD_BUILD && SWCOMP_ZIP_POD_BZ2)
                break
            #else
                throw ZipError.compressionNotSupported
            #endif
        case 14:
            #if (!SWCOMP_ZIP_POD_BUILD) || (SWCOMP_ZIP_POD_BUILD && SWCOMP_ZIP_POD_LZMA)
                break
            #else
                throw ZipError.compressionNotSupported
            #endif
        default:
            throw ZipError.compressionNotSupported
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

    let fileName: String
    let fileComment: String?

    private(set) var diskNumberStart: UInt32

    let internalFileAttributes: Int
    let externalFileAttributes: UInt32

    private(set) var offset: UInt64

    init(_ pointerData: inout DataWithPointer, _ currentDiskNumber: UInt32) throws {
        // Check signature.
        guard pointerData.uint32FromAlignedBytes(count: 4) == 0x02014b50
            else { throw ZipError.wrongSignature }

        self.versionMadeBy = pointerData.intFromAlignedBytes(count: 2)
        self.versionNeeded = pointerData.intFromAlignedBytes(count: 2)

        self.generalPurposeBitFlags = pointerData.intFromAlignedBytes(count: 2)

        self.compressionMethod = pointerData.intFromAlignedBytes(count: 2)

        self.lastModFileTime = pointerData.intFromAlignedBytes(count: 2)
        self.lastModFileDate = pointerData.intFromAlignedBytes(count: 2)

        self.crc32 = pointerData.uint32FromAlignedBytes(count: 4)

        self.compSize = pointerData.uint64FromAlignedBytes(count: 4)
        self.uncompSize = pointerData.uint64FromAlignedBytes(count: 4)

        let fileNameLength = pointerData.intFromAlignedBytes(count: 2)
        let extraFieldLength = pointerData.intFromAlignedBytes(count: 2)
        let fileCommentLength = pointerData.intFromAlignedBytes(count: 2)

        self.diskNumberStart = pointerData.uint32FromAlignedBytes(count: 2)

        self.internalFileAttributes = pointerData.intFromAlignedBytes(count: 2)
        self.externalFileAttributes = pointerData.uint32FromAlignedBytes(count: 4)

        self.offset = pointerData.uint64FromAlignedBytes(count: 4)

        guard let fileName = String(data: Data(bytes: pointerData.alignedBytes(count: fileNameLength)),
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
                    self.diskNumberStart = pointerData.uint32FromAlignedBytes(count: 4)
                }
            default:
                pointerData.index += size
            }
        }

        guard let fileComment = String(data: Data(bytes: pointerData.alignedBytes(count: fileCommentLength)),
                                    encoding: .utf8)
            else { throw ZipError.wrongTextField }
        self.fileComment = fileComment

        // Let's check entry's values for consistency.
        guard self.versionNeeded <= 45
            else { throw ZipError.wrongVersion }
        guard self.diskNumberStart == currentDiskNumber
            else { throw ZipError.multiVolumesNotSupported }
        guard self.generalPurposeBitFlags & 0x2000 == 0 ||
            self.generalPurposeBitFlags & 0x40 == 0 ||
            self.generalPurposeBitFlags & 0x01 == 0
            else { throw ZipError.encryptionNotSupported }
        guard self.generalPurposeBitFlags & 0x20 == 0
            else { throw ZipError.patchingNotSupported }

        switch self.compressionMethod {
        case 0:
            break
        case 8:
            break
        case 12:
            #if (!SWCOMP_ZIP_POD_BUILD) || (SWCOMP_ZIP_POD_BUILD && SWCOMP_ZIP_POD_BZ2)
                break
            #else
                throw ZipError.compressionNotSupported
            #endif
        case 14:
            #if (!SWCOMP_ZIP_POD_BUILD) || (SWCOMP_ZIP_POD_BUILD && SWCOMP_ZIP_POD_LZMA)
                break
            #else
                throw ZipError.compressionNotSupported
            #endif
        default:
            throw ZipError.compressionNotSupported
        }
    }

}

struct EndOfCentralDirectory {

    /// Number of the current disk.
    private(set) var currentDiskNumber: UInt32

    /// Number of the disk with the start of CD.
    private(set) var cdDiskNumber: UInt32
    private(set) var cdEntries: UInt64
    private(set) var cdSize: UInt64
    private(set) var cdOffset: UInt64

    init(_ pointerData: inout DataWithPointer) throws {
        /// Indicates if Zip64 records should be present.
        var zip64RecordExists = false

        self.currentDiskNumber = pointerData.uint32FromAlignedBytes(count: 2)
        self.cdDiskNumber = pointerData.uint32FromAlignedBytes(count: 2)
        guard self.currentDiskNumber == self.cdDiskNumber
            else { throw ZipError.multiVolumesNotSupported }

        /// Number of CD entries on the current disk.
        var cdEntriesCurrentDisk = pointerData.uint64FromAlignedBytes(count: 2)
        /// Total number of CD entries.
        self.cdEntries = pointerData.uint64FromAlignedBytes(count: 2)
        guard cdEntries == cdEntriesCurrentDisk
            else { throw ZipError.multiVolumesNotSupported }

        /// Size of Central Directory.
        self.cdSize = pointerData.uint64FromAlignedBytes(count: 4)
        /// Offset to the start of Central Directory.
        self.cdOffset = pointerData.uint64FromAlignedBytes(count: 4)
        let zipCommentLength = pointerData.intFromAlignedBytes(count: 2)

        // Check if zip64 records are present.
        if self.currentDiskNumber == 0xFFFF || self.cdDiskNumber == 0xFFFF ||
            cdEntriesCurrentDisk == 0xFFFF || self.cdEntries == 0xFFFF ||
            self.cdSize == 0xFFFFFFFF || self.cdOffset == 0xFFFFFFFF {
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
            guard pointerData.uint32FromAlignedBytes(count: 4) == 0x07064b50
                else { throw ZipError.wrongSignature }

            let zip64CDStartDisk = pointerData.uint32FromAlignedBytes(count: 4)
            guard self.currentDiskNumber == zip64CDStartDisk
                else { throw ZipError.multiVolumesNotSupported }

            let zip64CDEndOffset = pointerData.uint64FromAlignedBytes(count: 8)
            let totalDisks = pointerData.uint64FromAlignedBytes(count: 1)
            guard totalDisks == 1
                else { throw ZipError.multiVolumesNotSupported }

            // Now we need to move to Zip64 End of CD.
            pointerData.index = Int(UInt(truncatingBitPattern: zip64CDEndOffset))

            // Check signature.
            guard pointerData.uint32FromAlignedBytes(count: 4) == 0x06064b50
                else { throw ZipError.wrongSignature }

            // Following 8 bytes are size of end of zip64 CD, but we don't need it.
            _ = pointerData.uint64FromAlignedBytes(count: 8)

            // Next two bytes are version of compressor, but we don't need it.
            _ = pointerData.uint64FromAlignedBytes(count: 2)
            let versionNeeded = pointerData.uint64FromAlignedBytes(count: 2)
            guard versionNeeded <= 45
                else { throw ZipError.wrongVersion }

            // Update values read from basic End of CD with the ones from Zip64 End of CD.
            self.currentDiskNumber = pointerData.uint32FromAlignedBytes(count: 4)
            self.cdDiskNumber = pointerData.uint32FromAlignedBytes(count: 4)
            guard currentDiskNumber == cdDiskNumber
                else { throw ZipError.multiVolumesNotSupported }

            cdEntriesCurrentDisk = pointerData.uint64FromAlignedBytes(count: 8)
            self.cdEntries = pointerData.uint64FromAlignedBytes(count: 8)
            guard cdEntries == cdEntriesCurrentDisk
                else { throw ZipError.multiVolumesNotSupported }

            self.cdSize = pointerData.uint64FromAlignedBytes(count: 8)
            self.cdOffset = pointerData.uint64FromAlignedBytes(count: 8)

            // Then, there might be 'zip64 extensible data sector' with 'special purpose data'.
            // But we don't need them currently, so let's skip them.

            // To find the size of these data:
            // let specialPurposeDataSize = zip64EndCDSize - 56
        }
    }

}
