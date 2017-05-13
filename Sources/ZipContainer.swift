//
//  ZipContainer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.01.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during processing ZIP archive (container).
 It may indicate that either the data is damaged or it might not be ZIP archive (container) at all.

 - `notFoundCentralDirectoryEnd`: end of Central Directoty record wasn't found.
 - `wrongSignature`: unsupported signature of one of ZIP container's structures.
 - `wrongSize`: incorrect compressed or uncompressed size of a ZIP container's entry's data.
 - `wrongVersion`: unsupported number of version needed to extract ZIP container
    (unsupported features are required to open this file).
 - `multiVolumesNotSupported`: unsupported feature: multi-volumed or spanned container.
 - `encryptionNotSupported`: unsupported feature: encryption.
 - `patchingNotSupported`: unsupported feature: patched data.
 - `compressionNotSupported`: unsupported feature: specified compression method.
 - `wrongLocalHeader`: local header of an entry wasn't consistent with Central Directory record.
 - `wrongCRC32`: computed checksum of entry's data wasn't the same as the one stored in container.
 */
public enum ZipError: Error {
    /// End of Central Directoty record was not found.
    case notFoundCentralDirectoryEnd
    /// Wrong signature of one of ZIP container's structures.
    case wrongSignature
    /// Wrong either compressed or uncompressed size of a ZIP container's entry.
    case wrongSize
    /// Wrong number of version needed to extract ZIP container.
    case wrongVersion
    /// Archive either spanned or consists of several volumes. This feature is not supported.
    case multiVolumesNotSupported
    /// Entry or record is encrypted. This feature is not supported.
    case encryptionNotSupported
    /// Entry contains patched data. This feature is not supported.
    case patchingNotSupported
    /// Wrong compression method of an entry.
    case compressionNotSupported
    /// Wrong local header of an entry.
    case wrongLocalHeader
    /**
     Computed CRC32 of entry's data didn't match the value stored in the container.
     Associated value contains extracted data.
     */
    case wrongCRC32(Data)
    case wrongTextField
}

/// Represents either a file or directory entry inside ZIP archive.
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

    /// File or directory attributes related to the file system of archive's creator.
    public var attributes: UInt32 {
        return self.cdEntry.externalFileAttributes
    }

    public var size: Int {
        return Int(truncatingBitPattern: cdEntry.uncompSize)
    }

    /**
     True, if an entry is likely to be a directory.
     Particularly, it is true if size of data is 0 and last character of entry's name is '/'.
    */
    public var isDirectory: Bool {
        return self.size == 0 && self.name.characters.last == "/"
    }

    /**
     Returns data associated with this entry.

     - Note: Returned `Data` object with the size of 0 can either indicate that the entry is an empty file
     or it is a directory.

     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of inconsistency in data.
     An error can indicate that the container is damaged.
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
            compSize = Int(pointerData.uint32FromAlignedBytes(count: 4))
            uncompSize = Int(pointerData.uint32FromAlignedBytes(count: 4))
        }

        guard compSize == realCompSize && uncompSize == fileBytes.count
            else { throw ZipError.wrongSize }
        guard crc32 == UInt32(CheckSums.crc32(fileBytes))
            else { throw ZipError.wrongCRC32(Data(bytes: fileBytes)) }

        return Data(bytes: fileBytes)
    }

    init(_ cdEntry: CentralDirectoryEntry, _ pointerData: inout DataWithPointer) {
        self.cdEntry = cdEntry
        self.pointerData = pointerData
    }

}

/// Provides function which opens ZIP archives (containers).
public class ZipContainer: Container {

    /**
     Processes ZIP archive (container) and returns an array of `ContainerEntries` (which are actually `ZipEntries`).
     First member of a tuple is entry's name, second member is entry's data.
     
     - Important: The order of entries is defined by ZIP archive and, particularly, creator of given ZIP container.
     It is likely that directories will be encountered earlier than files stored in those directories,
     but one SHOULD NOT assume that this is the case.
     
     - Note: Currently, there is no universal (platform and file system independent) method to determine if entry is a directory.
     One can check this by looking at the size of entry's data (it should be 0 for directory) AND
     the last character of entry's name (it should be '/'). If all of these is true then entry is likely to be a directory.

     - Parameter containerData: Data of ZIP container.
     
     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of inconsistency in data.
     It may indicate that either the container is damaged or it might not be ZIP container at all.

     - Returns: Array of pairs `ZipEntries` as an array of `ContainerEntries`.
     */
    public static func open(containerData: Data) throws -> [ContainerEntry] {

        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: containerData, bitOrder: .reversed)
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

    private(set) var currentDiskNumber: UInt32
    private(set) var cdDiskNumber: UInt32
    private(set) var cdEntries: UInt64
    private(set) var cdSize: UInt64
    private(set) var cdOffset: UInt64

    init(_ pointerData: inout DataWithPointer) throws {
        /// Indicates if Zip64 records should be present.
        var zip64RecordExists = false

        /// Number of current disk.
        self.currentDiskNumber = pointerData.uint32FromAlignedBytes(count: 2)
        /// Number of the disk with the start of CD.
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
