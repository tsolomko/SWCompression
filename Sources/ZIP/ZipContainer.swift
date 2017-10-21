// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides open function for ZIP containers.
public class ZipContainer: Container {

    /**
     Processes ZIP container and returns an array of `ContainerEntry` (which are actually `ZipEntry`).

     - Important: The order of entries is defined by ZIP container and,
     particularly, by the creator of a given ZIP container.
     It is likely that directories will be encountered earlier than files stored in those directories,
     but one SHOULD NOT rely on any particular order.

     - Parameter container: ZIP container's data.

     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of the problem.
     It may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntry` as an array of `ContainerEntry`.
     */
    public static func open(container data: Data) throws -> [ZipEntry] {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)
        var entries = [ZipEntry]()

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
        pointerData.index = Int(UInt(truncatingIfNeeded: endOfCD.cdOffset))

        for _ in 0..<cdEntries {
            let info = try ZipEntryInfo(pointerData)
            try info.cdEntry.validate(endOfCD.currentDiskNumber)

            let savedDataIndex = pointerData.index
            let data = try ZipContainer.getEntryData(pointerData, info)
            pointerData.index = savedDataIndex
            entries.append(ZipEntry(info, data))
        }

        return entries
    }

    // TODO: temporary
    private static func getEntryData(_ pointerData: DataWithPointer, _ info: ZipEntryInfo) throws -> Data {
        // Now, let's move to the location of local header.
        pointerData.index = Int(UInt32(truncatingIfNeeded: info.cdEntry.offset))

        let localHeader = try ZipLocalHeader(pointerData)
        // Check local header for consistency with Central Directory entry.
        try localHeader.validate(with: info.cdEntry)

        let hasDataDescriptor = localHeader.generalPurposeBitFlags & 0x08 != 0

        // If file has data descriptor, then some values in local header are absent.
        // So we need to use values from CD entry.
        var uncompSize = hasDataDescriptor ?
            Int(UInt32(truncatingIfNeeded: info.cdEntry.uncompSize)) :
            Int(UInt32(truncatingIfNeeded: localHeader.uncompSize))
        var compSize = hasDataDescriptor ?
            Int(UInt32(truncatingIfNeeded: info.cdEntry.compSize)) :
            Int(UInt32(truncatingIfNeeded: localHeader.compSize))
        var crc32 = hasDataDescriptor ? info.cdEntry.crc32 : localHeader.crc32

        let fileBytes: [UInt8]
        let fileDataStart = pointerData.index
        switch localHeader.compressionMethod {
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
            let sizeOfSizeField: UInt64 = localHeader.zip64FieldsArePresent ? 8 : 4
            compSize = Int(pointerData.uint64(count: sizeOfSizeField))
            uncompSize = Int(pointerData.uint64(count: sizeOfSizeField))
        }

        guard compSize == realCompSize && uncompSize == fileBytes.count
            else { throw ZipError.wrongSize }
        guard crc32 == UInt32(CheckSums.crc32(fileBytes))
            else { throw ZipError.wrongCRC32(Data(bytes: fileBytes)) }

        return Data(bytes: fileBytes)
    }

    public static func info(container: Data) throws -> [ZipEntryInfo] {
        return []
    }

}
