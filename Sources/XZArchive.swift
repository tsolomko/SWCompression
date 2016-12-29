//
//  XzArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 18.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during unarchiving xz archive.
 It may indicate that either the data is damaged or it might not be xz archive at all.

 - `WrongMagic`: 'magic' bytes in archive's header or footer weren't equal to predefined value.
 - `WrongArchiveInfo`: incorrect value of one of archive's special field (in block, index, header or footer).
 - `FieldReservedValue`: value of one of archive's special field 
    (in block, index, header or footer) had reserved value.
 - `WrongInfoCRC`: incorrect value of one of archive's special field (in block, index, header or footer).
 - `WrongFilterID`: unsupported value of filter ID (not LZMA2's 0x21).
 - `CheckTypeSHA256`: checksum's type was SHA-256.
 - `WrongDataSize`: size of compressed or decompressed data wasn't the same as specified in block.
 - `WrongCheck`: computed checksum of uncompressed data didn't match the archive's value.
    Associated value contains already decompressed data.
 - `WrongPadding`: unsupported padding of one of structures in the archive.
 - `MultiByteIntegerError`: error happened during reading of one of so called 'multi-byte' numbers.
 */
public enum XZError: Error {
    /// Either magic number in header or footer was not equal to predefined value.
    case WrongMagic
    /// One of special fields of archive had an incorrect value.
    case WrongArchiveInfo
    /// One of special fields of archive had a reserved value.
    case FieldReservedValue
    /// Checksum of one of special fields of archive was incorrect.
    case WrongInfoCRC
    /// ID of filter(s) used in archvie was unsupported.
    case WrongFilterID
    /// Type of checksum of archive was SHA-256.
    case CheckTypeSHA256
    /**
     Either size of decompressed data was not equal to specified one in block header or
     amount of compressed data read was different from the one stored in block header.
     */
    case WrongDataSize
    /**
     Computed checksum of uncompressed data didn't match the value stored in the archive.
     Associated value contains already decompressed data.
     */
    case WrongCheck(Data)
    /// Unsupported padding of a structure in the archive.
    case WrongPadding
    /// Either null byte encountered or exceeded maximum amount bytes during reading multi byte number.
    case MultiByteIntegerError
}

/// A class with unarchive function for xz archives.
public final class XZArchive: Archive {

    /**
     Unarchives xz archive stored in `archiveData`.

     If data passed is not actually a xz archive, `XZError` will be thrown.
     If filters other than LZMA2 are used in archive then `XZError.WrongFilterID` will be thrown.

     If data inside the archive is not actually compressed with LZMA2,
     `LZMAError` or `LZMA2Error` will be thrown.

     - Parameter archiveData: Data compressed with xz.

     - Throws: `LZMAError`, `LZMA2Error` or `XZError` depending on the type of inconsistency in data.
     It may indicate that either the data is damaged or it might not be compressed with xz or LZMA(2) at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archiveData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        var out: [UInt8] = []

        streamLoop: while !pointerData.isAtTheEnd {
            // STREAM HEADER
            let streamHeader = try processStreamHeader(&pointerData)

            // BLOCKS AND INDEX
            /// Zero value of blockHeaderSize means that we encountered INDEX.
            var blockInfos: [(unpaddedSize: Int, uncompSize: Int)] = []
            var indexSize = -1
            while true {
                let blockHeaderSize = pointerData.alignedByte()
                if blockHeaderSize == 0 {
                    indexSize = try processIndex(blockInfos, &pointerData)
                    break
                } else {
                    let blockInfo = try processBlock(blockHeaderSize, &pointerData)
                    out.append(contentsOf: blockInfo.blockData)
                    let checkSize: Int
                    switch streamHeader.checkType {
                    case 0x00:
                        checkSize = 0
                        break
                    case 0x01:
                        checkSize = 4
                        let check = pointerData.intFromAlignedBytes(count: 4)
                        guard CheckSums.crc32(blockInfo.blockData) == check
                            else { throw XZError.WrongCheck(Data(bytes: out)) }
                    case 0x04:
                        checkSize = 8
                        let check = pointerData.uint64FromAlignedBytes(count: 8)
                        guard CheckSums.crc64(blockInfo.blockData) == check
                            else { throw XZError.WrongCheck(Data(bytes: out)) }
                    case 0x0A:
                        throw XZError.CheckTypeSHA256
                    default:
                        throw XZError.FieldReservedValue
                    }
                    blockInfos.append((blockInfo.unpaddedSize + checkSize, blockInfo.uncompressedSize))
                }
            }

            // STREAM FOOTER
            try processFooter(streamHeader, indexSize, &pointerData)

            guard !pointerData.isAtTheEnd else { break streamLoop }

            // STREAM PADDING
            var paddingBytes = 0
            while true {
                let byte = pointerData.alignedByte()
                if byte != 0 {
                    if paddingBytes % 4 != 0 {
                        throw XZError.WrongPadding
                    } else {
                        break
                    }
                }
                paddingBytes += 1
            }
            pointerData.index -= 1
        }

        return Data(bytes: out)
    }

    private static func processStreamHeader(_ pointerData: inout DataWithPointer) throws -> (checkType: Int, flagsCRC: Int) {
        // Check magic number.
        guard pointerData.uint64FromAlignedBytes(count: 6) == 0x005A587A37FD
            else { throw XZError.WrongMagic }

        // First byte of flags must be equal to zero.
        guard pointerData.alignedByte() == 0
            else { throw XZError.FieldReservedValue }

        // Next four bits indicate type of redundancy check.
        let checkType = pointerData.intFromBits(count: 4)
        switch checkType {
        case 0x00, 0x01, 0x04, 0x0A:
            break
        default:
            throw XZError.FieldReservedValue
        }

        // Final four bits must be equal to zero.
        guard pointerData.intFromBits(count: 4) == 0
            else { throw XZError.FieldReservedValue }

        // CRC-32 of flags must be equal to the value in archive.
        let flagsCRC = pointerData.intFromAlignedBytes(count: 4)
        guard CheckSums.crc32([0, checkType.toUInt8()]) == flagsCRC
            else { throw XZError.WrongInfoCRC }

        return (checkType, flagsCRC)
    }

    private static func processBlock(_ blockHeaderSize: UInt8,
                                     _ pointerData: inout DataWithPointer)  throws -> (blockData: [UInt8], unpaddedSize: Int, uncompressedSize: Int) {
        var blockBytes: [UInt8] = []
        let blockHeaderStartIndex = pointerData.index - 1
        blockBytes.append(blockHeaderSize)
        guard blockHeaderSize >= 0x01 && blockHeaderSize <= 0xFF
            else { throw XZError.WrongArchiveInfo }
        let realBlockHeaderSize = (blockHeaderSize + 1) * 4

        let blockFlags = pointerData.alignedByte()
        blockBytes.append(blockFlags)
        /**
         Bit values 00, 01, 10, 11 indicate filters number from 1 to 4,
         so we actually need to add 1 to get filters' number.
         */
        let numberOfFilters = blockFlags & 0x03 + 1
        guard blockFlags & 0x3C == 0
            else { throw XZError.FieldReservedValue }

        /// Should match size of compressed data.
        var compressedSize = -1
        if blockFlags & 0x40 != 0 {
            let compressedSizeDecodeResult = try pointerData.multiByteDecode()
            compressedSize = compressedSizeDecodeResult.multiByteInteger
            guard compressedSize > 0
                else { throw XZError.WrongArchiveInfo }
            blockBytes.append(contentsOf: compressedSizeDecodeResult.bytesProcessed)
        }

        /// Should match the size of data after decompression.
        var uncompressedSize = -1
        if blockFlags & 0x80 != 0 {
            let uncompressedSizeDecodeResult = try pointerData.multiByteDecode()
            uncompressedSize = uncompressedSizeDecodeResult.multiByteInteger
            guard uncompressedSize > 0
                else { throw XZError.WrongArchiveInfo }
            blockBytes.append(contentsOf: uncompressedSizeDecodeResult.bytesProcessed)
        }

        var filters: [(inout DataWithPointer) throws -> [UInt8]] = []
        for _ in 0..<numberOfFilters {
            let filterIDTuple = try pointerData.multiByteDecode()
            let filterID = filterIDTuple.multiByteInteger
            blockBytes.append(contentsOf: filterIDTuple.bytesProcessed)
            guard UInt64(filterID) < 0x4000000000000000
                else { throw XZError.WrongFilterID }
            // Only LZMA2 filter is supported.
            switch filterID {
            case 0x21: // LZMA2
                // First, we need to skip byte with the size of filter's properties
                blockBytes.append(contentsOf: try pointerData.multiByteDecode().bytesProcessed)
                /// In case of LZMA2 filters property is a dicitonary size.
                let filterPropeties = pointerData.alignedByte()
                blockBytes.append(filterPropeties)
                let closure = { (dwp: inout DataWithPointer) -> [UInt8] in
                    try LZMA2.decompress(LZMA2.dictionarySize(filterPropeties), &dwp)
                }
                filters.append(closure)
            default:
                throw XZError.WrongFilterID
            }
        }

        // We need to take into account 4 bytes for CRC32 so thats why "-4".
        while pointerData.index - blockHeaderStartIndex < realBlockHeaderSize.toInt() - 4 {
            let byte = pointerData.alignedByte()
            guard byte == 0x00
                else { throw XZError.WrongPadding }
            blockBytes.append(byte)
        }

        let blockHeaderCRC = pointerData.intFromAlignedBytes(count: 4)
        guard CheckSums.crc32(blockBytes) == blockHeaderCRC
            else { throw XZError.WrongInfoCRC }

        var intResult = pointerData
        let compressedDataStart = pointerData.index
        for filterIndex in 0..<numberOfFilters - 1 {
            var arrayResult = try filters[numberOfFilters.toInt() - filterIndex.toInt() - 1](&intResult)
            intResult = DataWithPointer(array: &arrayResult, bitOrder: intResult.bitOrder)
        }
        guard compressedSize == -1 || compressedSize == pointerData.index - compressedDataStart
            else { throw XZError.WrongDataSize }

        let out = try filters[numberOfFilters.toInt() - 1](&intResult)
        guard uncompressedSize == -1 || uncompressedSize == out.count
            else { throw XZError.WrongDataSize }

        let unpaddedSize = pointerData.index - blockHeaderStartIndex

        if unpaddedSize % 4 != 0 {
            let paddingSize = 4 - unpaddedSize % 4
            for _ in 0..<paddingSize {
                let byte = pointerData.alignedByte()
                guard byte == 0x00
                    else { throw XZError.WrongPadding }
            }
        }

        return (out, unpaddedSize, out.count)
    }

    private static func processIndex(_ blockInfos: [(unpaddedSize: Int, uncompSize: Int)],
                                     _ pointerData: inout DataWithPointer) throws -> Int {
        var indexBytes: [UInt8] = [0x00]
        let numberOfRecordsTuple = try pointerData.multiByteDecode()
        indexBytes.append(contentsOf: numberOfRecordsTuple.bytesProcessed)
        let numberOfRecords = numberOfRecordsTuple.multiByteInteger
        guard numberOfRecords == blockInfos.count
            else { throw XZError.WrongArchiveInfo }
        for blockInfo in blockInfos {
            let unpaddedSizeTuple = try pointerData.multiByteDecode()
            guard unpaddedSizeTuple.multiByteInteger == blockInfo.unpaddedSize
                else { throw XZError.WrongArchiveInfo }
            indexBytes.append(contentsOf: unpaddedSizeTuple.bytesProcessed)

            let uncompSizeTuple = try pointerData.multiByteDecode()
            guard uncompSizeTuple.multiByteInteger == blockInfo.uncompSize
                else { throw XZError.WrongDataSize }
            indexBytes.append(contentsOf: uncompSizeTuple.bytesProcessed)
        }

        if indexBytes.count % 4 != 0 {
            let paddingSize = 4 - indexBytes.count % 4
            for _ in 0..<paddingSize {
                let byte = pointerData.alignedByte()
                guard byte == 0x00
                    else { throw XZError.WrongPadding }
                indexBytes.append(byte)
            }
        }

        let indexCRC = pointerData.intFromAlignedBytes(count: 4)
        guard CheckSums.crc32(indexBytes) == indexCRC
            else { throw XZError.WrongInfoCRC }

        return indexBytes.count + 4
    }

    private static func processFooter(_ streamHeader: (checkType: Int, flagsCRC: Int),
                                      _ indexSize: Int,
                                      _ pointerData: inout DataWithPointer) throws {
        let footerCRC = pointerData.intFromAlignedBytes(count: 4)
        let storedBackwardSize = pointerData.alignedBytes(count: 4)
        let footerStreamFlags = pointerData.alignedBytes(count: 2)
        guard CheckSums.crc32([storedBackwardSize, footerStreamFlags].flatMap { $0 }) == footerCRC
            else { throw XZError.WrongInfoCRC }

        /// Indicates the size of Index field. Should match its real size.
        var realBackwardSize = 0
        for i in 0..<4 {
            realBackwardSize |= storedBackwardSize[i].toInt() << (8 * i)
        }
        realBackwardSize += 1
        realBackwardSize *= 4
        guard realBackwardSize == indexSize
            else { throw XZError.WrongArchiveInfo }

        // Flags in the footer should be the same as in the header.
        guard footerStreamFlags[0] == 0
            else { throw XZError.FieldReservedValue }
        guard footerStreamFlags[1] & 0x0F == streamHeader.checkType.toUInt8()
            else { throw XZError.WrongArchiveInfo }
        guard footerStreamFlags[1] & 0xF0 == 0
            else { throw XZError.FieldReservedValue }

        // Check footer's magic number
        guard pointerData.intFromAlignedBytes(count: 2) == 0x5A59
            else { throw XZError.WrongMagic }
    }

}

extension DataWithPointer {
    func multiByteDecode() throws -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        var i = 1
        var result = self.alignedByte().toInt()
        var bytes: [UInt8] = [result.toUInt8()]
        if result <= 127 {
            return (result, bytes)
        }
        result &= 0x7F
        while self.bitArray[self.index - 1] & 0x80 != 0 {
            let byte = self.alignedByte()
            if i >= 9 || byte == 0x00 {
                throw XZError.MultiByteIntegerError
            }
            bytes.append(byte)
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return (result, bytes)
    }
}
