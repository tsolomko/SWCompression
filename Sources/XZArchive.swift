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

 - `WrongMagic`: first two bytes of archive weren't `{ 0xFD, '7', 'z', 'X', 'Z', 0x00 }`.
 - `WrongFlagsFirstByte`: first byte of the flags wasn't zero.
 - `WrongCheckType`: unsupported check type (not 0x00, 0x01, 0x04 or 0x0A).
 - `WrongFlagsLastFourBits`: last four bits of the flags weren't zero.
 - `WrongFlagsCRC`: calculated crc-32 for flags doesn't equal to the value stored in the archive.
 - `WrongFooterFlagsFirstByte`: first byte of the flags in the footer wasn't zero.
 - `WrongFooterCheckType`: check type in the footer wasn't equal to the one in the header.
 - `WrongFooterFlagsLastFourBits`: last four bits of the flags in the footer weren't zero.
 - `WrongFooterCRC`: calculated crc-32 for footer's fields doesn't equal to the value stored in the archive.
 - `WrongStreamPadding`: the size of stream padding wasn't multiple of four.
 - `WrongBlockHeaderSize`: unsuported size of block's header (not in 0x01-0xFF range).
 - `WrongBlockFlags`: unsupported block flags.
 */
public enum XZError: Error {
    /// First six bytes of archive were not equal to 0xFD377A585A00.
    case WrongMagic
    /// First byte of the flags was not equal to zero.
    case WrongFlagsFirstByte
    /// Type of check was equal to one of the reserved values.
    case WrongCheckType
    /// Last four bits of the flags were not equal to zero.
    case WrongFlagsLastFourBits
    /// Checksum for flags is incorrect.
    case WrongFlagsCRC
    /// First byte of the flags field in footer was not equal to zero.
    case WrongFooterFlagsFirstByte
    /// Type of check in the footer was not equal to one from the header's flags.
    case WrongFooterCheckType
    /// Last four bits of the flags in footer were not equal to zero.
    case WrongFooterFlagsLastFourBits
    /// Checksum for fields in footer is incorrect.
    case WrongFooterCRC
    /// Size of stream padding was not multiple of four.
    case WrongStreamPadding
    /// Size of the block header is not in range from 0x01 to 0xFF.
    case WrongBlockHeaderSize
    /// Reserved flags of a block were set.
    case WrongBlockFlags

    case MultiByteIntegerError
    case WrongCompressedSize
    case WrongUncompressedSize
    case WrongFilterID
    case WrongBlockHeaderPadding
    case WrongBlocksCRC
}

/// A class with unarchive function for xz archives.
public class XZArchive: Archive {

    private struct StreamHeader {
        let checkType: Int
        let flagsCRC: Int
    }

    /**
     Unarchives xz archive stored in `archiveData`.

     If data passed is not actually a xz archive, `XZError` will be thrown.

     If data inside the archive is not actually compressed with LZMA algorithm, `LZMAError` will be thrown.

     - Parameter archiveData: Data compressed with xz.

     - Throws: `LZMAError` or `XZError` depending on the type of inconsistency in data.
     It may indicate that either the data is damaged or it might not be compressed with xz or LZMA at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archiveData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        // STREAM HEADER

        let streamHeader = try processStreamHeader(&pointerData)

        // BLOCKS AND INDEX
        /// Zero value of blockHeaderSize means that we encountered INDEX.
        let blockHeaderSize = pointerData.alignedByte()
        if blockHeaderSize == 0 {
            try processIndex(&pointerData)
        } else {
            try processBlock(blockHeaderSize, &pointerData)
        }

        // STREAM FOOTER
        try processFooter(streamHeader, &pointerData)

        // STREAM PADDING
        var paddingBytes = 0
        while true {
            let byte = pointerData.alignedByte()
            if byte != 0 {
                if paddingBytes % 4 != 0 {
                    throw XZError.WrongStreamPadding
                } else {
                    break
                }
            }
            paddingBytes += 1
        }
        pointerData.index -= 1

        return try LZMA.decompress(&pointerData)
    }

    private static func processStreamHeader(_ pointerData: inout DataWithPointer) throws -> StreamHeader {
        // Check magic number.
        guard pointerData.intFromAlignedBytes(count: 6) == 0x005A587A37FD
            else { throw XZError.WrongMagic }

        // First byte of flags must be equal to zero.
        guard pointerData.alignedByte() == 0
            else { throw XZError.WrongFlagsFirstByte }

        // Next four bits indicate type of redundancy check.
        let checkType = pointerData.intFromBits(count: 4)
        switch checkType {
        case 0x00, 0x01, 0x04, 0x0A:
            break
        default:
            throw XZError.WrongCheckType
        }

        // Final four bits must be equal to zero.
        guard pointerData.intFromBits(count: 4) == 0
            else { throw XZError.WrongFlagsLastFourBits }

        // CRC-32 of flags must be equal to the value in archive.
        let flagsCRC = pointerData.intFromAlignedBytes(count: 4)
        guard CheckSums.crc32([0, checkType.toUInt8()]) == flagsCRC
            else { throw XZError.WrongFlagsCRC }

        return StreamHeader(checkType: checkType, flagsCRC: flagsCRC)
    }

    private static func processBlock(_ blockHeaderSize: UInt8, _ pointerData: inout DataWithPointer) throws {
        var blockBytes: [UInt8] = []
        let blockHeaderStartIndex = pointerData.index - 1
        blockBytes.append(blockHeaderSize)
        guard blockHeaderSize >= 0x01 && blockHeaderSize <= 0xFF
            else { throw XZError.WrongBlockHeaderSize }
        let realBlockHeaderSize = (blockHeaderSize + 1) * 4

        let blockFlags = pointerData.alignedByte()
        blockBytes.append(blockFlags)
        /**
         Bit values 00, 01, 10, 11 indicate filters number from 1 to 4,
         so we actually need to add 1 to get filters' number.
         */
        let numberOfFilters = blockFlags & 0x03 + 1
        guard blockFlags & 0x3C == 0
            else { throw XZError.WrongBlockFlags }

        /// Should match size of compressed data.
        var compressedSize = -1
        if blockFlags & 0x40 != 0 {
            let compressedSizeDecodeResult = try pointerData.multiByteDecode()
            compressedSize = compressedSizeDecodeResult.multiByteInteger
            guard compressedSize > 0
                else { throw XZError.WrongCompressedSize }
            blockBytes.append(contentsOf: compressedSizeDecodeResult.bytesProcessed)
        }

        /// Should match the size of data after decompression.
        var uncompressedSize = -1
        if blockFlags & 0x80 != 0 {
            let uncompressedSizeDecodeResult = try pointerData.multiByteDecode()
            uncompressedSize = uncompressedSizeDecodeResult.multiByteInteger
            guard uncompressedSize > 0
                else { throw XZError.WrongUncompressedSize }
            blockBytes.append(contentsOf: uncompressedSizeDecodeResult.bytesProcessed)
        }

        for _ in 0..<numberOfFilters {
            let filterID = try pointerData.multiByteDecode()
            guard filterID.multiByteInteger < 0x4000000000000000
                else { throw XZError.WrongFilterID }
            let sizeOfProperties = try pointerData.multiByteDecode()
            // TODO: Add parsing of filters' properties.
            // Don't forget to add this bytes to blockBytes
        }

        while pointerData.index - blockHeaderStartIndex < blockHeaderSize.toInt() {
            let byte = pointerData.alignedByte()
            blockBytes.append(byte)
            if byte != 0x00 {
                throw XZError.WrongBlockHeaderPadding
            }
        }

        let blockHeaderCRC = pointerData.intFromAlignedBytes(count: 4)
        guard CheckSums.crc32(blockBytes) == blockHeaderCRC
            else { throw XZError.WrongBlocksCRC }
    }

    private static func processIndex(_ pointerData: inout DataWithPointer) throws {

    }

    private static func processFooter(_ streamHeader: StreamHeader,
                                      _ pointerData: inout DataWithPointer) throws {
        let footerCRC = pointerData.intFromAlignedBytes(count: 4)
        let storedBackwardSize = pointerData.alignedBytes(count: 4)
        let footerStreamFlags = pointerData.alignedBytes(count: 2)
        guard CheckSums.crc32([storedBackwardSize, footerStreamFlags].flatMap { $0 }) == footerCRC
            else { throw XZError.WrongFooterCRC }

        /// Indicates the size of Index field. Should match its real size.
        var realBackwardSize = 0
        for i in 0..<4 {
            realBackwardSize |= storedBackwardSize[i].toInt() << (8 * i)
        }
        realBackwardSize += 1
        realBackwardSize *= 4

        // Flags in the footer should be the same as in the header.
        guard footerStreamFlags[0] == 0
            else { throw XZError.WrongFooterFlagsFirstByte }
        guard footerStreamFlags[1] & 0x0F == streamHeader.checkType.toUInt8()
            else { throw XZError.WrongFooterCheckType }
        guard footerStreamFlags[1] & 0xF0 == 0
            else { throw XZError.WrongFooterFlagsLastFourBits }

        // Check footer's magic number
        guard pointerData.intFromAlignedBytes(count: 2) == 0x5A59
            else { throw XZError.WrongMagic }
    }

}

fileprivate extension DataWithPointer {

    func multiByteDecode() throws -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        var num: UInt8 = 0
        var bytes: [UInt8] = []
        var i = 0
        var result = 0
        while true {
            let byte = self.alignedByte()
            if byte <= 127 && i == 0 {
                return (byte.toInt(), [byte])
            }
            if byte & 0x80 != 0 {
                self.index -= 1
                break
            }
            bytes.append(byte)
            if i >= 9 || byte == 0x00 {
                throw XZError.MultiByteIntegerError
            }
            num |= (byte & 0x7F) << (i.toUInt8() * 7)
            result = (result << 8) + byte.toInt()
            i += 1
        }
        return (result, bytes)
    }

}
