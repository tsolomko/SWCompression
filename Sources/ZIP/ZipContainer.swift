// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides functions for work with ZIP containers.
public class ZipContainer: Container {

    /**
     Processes ZIP container and returns an array of `ZipEntry` with information and data for all entries.

     - Important: The order of entries is defined by ZIP container and, particularly,
     by the creator of a given ZIP container. It is likely that directories will be encountered earlier
     than files stored in those directories, but one SHOULD NOT rely on any particular order.

     - Parameter container: ZIP container's data.

     - Throws: `ZipError` or any other error associated with compression type, depending on the type of the problem.
     It may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntry`.
     */
    public static func open(container data: Data) throws -> [ZipEntry] {
        let infos = try info(container: data)
        var entries = [ZipEntry]()

        for entryInfo in infos {
            if entryInfo.type == .directory {
                entries.append(ZipEntry(entryInfo, nil))
            } else {
                let entryDataResult = try ZipContainer.getEntryData(from: data, using: entryInfo)
                entries.append(ZipEntry(entryInfo, entryDataResult.data))
                guard !entryDataResult.crcError
                    else { throw ZipError.wrongCRC(entries) }
            }
        }

        return entries
    }

    private static func getEntryData(from data: Data, using info: ZipEntryInfo) throws -> (data: Data, crcError: Bool) {
        let hasDataDescriptor = info.localHeader.generalPurposeBitFlags & 0x08 != 0

        // If file has data descriptor, then some values in local header are absent.
        // So we need to use values from CD entry.
        var uncompSize = hasDataDescriptor ? info.cdEntry.uncompSize : info.localHeader.uncompSize
        var compSize = hasDataDescriptor ? info.cdEntry.compSize : info.localHeader.compSize
        var crc32 = hasDataDescriptor ? info.cdEntry.crc32 : info.localHeader.crc32

        let fileData: Data
        let pointerData = DataWithPointer(data: data)
        pointerData.index = info.localHeader.dataOffset
        switch info.compressionMethod {
        case .copy:
            fileData = Data(bytes: pointerData.bytes(count: Int(truncatingIfNeeded: uncompSize)))
        case .deflate:
            let bitReader = BitReader(data: pointerData.data, bitOrder: .reversed)
            bitReader.index = pointerData.index
            fileData = try Deflate.decompress(bitReader)
            // Sometimes `bitReader` has not-aligned state after Deflate decompression,
            //  so we need to align before getting end index back.
            bitReader.align()
            pointerData.index = bitReader.index
        case .bzip2:
            #if (!SWCOMPRESSION_POD_ZIP) || (SWCOMPRESSION_POD_ZIP && SWCOMPRESSION_POD_BZ2)
                // BZip2 algorithm considers bits in a byte in a different order.
                let bitReader = BitReader(data: pointerData.data, bitOrder: .straight)
                bitReader.index = pointerData.index
                fileData = try BZip2.decompress(bitReader)
                // Sometimes `bitReader` has not-aligned state after BZip2 decompression,
                //  so we need to align before getting end index back.
                bitReader.align()
                pointerData.index = bitReader.index
            #else
                throw ZipError.compressionNotSupported
            #endif
        case .lzma:
            #if (!SWCOMPRESSION_POD_ZIP) || (SWCOMPRESSION_POD_ZIP && SWCOMPRESSION_POD_LZMA)
                pointerData.index += 4 // Skipping LZMA SDK version and size of properties.
                fileData = try LZMA.decompress(pointerData, uncompressedSize: uncompSize)
            #else
                throw ZipError.compressionNotSupported
            #endif
        default:
            throw ZipError.compressionNotSupported
        }
        let realCompSize = pointerData.index - info.localHeader.dataOffset

        if hasDataDescriptor {
            // Now we need to parse data descriptor itself.
            // First, it might or might not have signature.
            let ddSignature = pointerData.uint32()
            if ddSignature != 0x08074b50 {
                pointerData.index -= 4
            }
            // Now, let's update with values from data descriptor.
            crc32 = pointerData.uint32()
            let sizeOfSizeField: UInt64 = info.localHeader.zip64FieldsArePresent ? 8 : 4
            compSize = pointerData.uint64(count: sizeOfSizeField)
            uncompSize = pointerData.uint64(count: sizeOfSizeField)
        }

        guard compSize == realCompSize && uncompSize == fileData.count
            else { throw ZipError.wrongSize }
        let crcError = crc32 != CheckSums.crc32(fileData)

        return (fileData, crcError)
    }

    /**
     Processes ZIP container and returns an array of `ZipEntryInfo` with information about entries in this container.

     - Important: The order of entries is defined by ZIP container and, particularly,
     by the creator of a given ZIP container. It is likely that directories will be encountered earlier
     than files stored in those directories, but one SHOULD NOT rely on any particular order.

     - Parameter container: ZIP container's data.

     - Throws: `ZipError`, which may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntryInfo`.
     */
    public static func info(container data: Data) throws -> [ZipEntryInfo] {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)
        var entries = [ZipEntryInfo]()

        pointerData.index = pointerData.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            // Check signature.
            if pointerData.uint32() == 0x06054b50 {
                // We found it!
                break
            }
            if pointerData.index == 0 {
                throw ZipError.notFoundCentralDirectoryEnd
            }
            pointerData.index -= 5
        }

        let endOfCD = try ZipEndOfCentralDirectory(pointerData)
        let cdEntries = endOfCD.cdEntries

        // OK, now we are ready to read Central Directory itself.
        var entryIndex = Int(truncatingIfNeeded: endOfCD.cdOffset)

        // First, check for "Archive extra data record" and skip it if present.
        pointerData.index = entryIndex
        if pointerData.uint32() == 0x08064b50 {
            entryIndex += Int(truncatingIfNeeded: pointerData.uint32())
        }

        for _ in 0..<cdEntries {
            let info = try ZipEntryInfo(data, entryIndex, endOfCD.currentDiskNumber)
            entries.append(info)
            entryIndex = info.cdEntry.nextEntryIndex
        }

        return entries
    }

}
