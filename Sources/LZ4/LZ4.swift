// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

public enum LZ4: DecompressionAlgorithm {

    public static func decompress(data: Data) throws -> Data {
        // Valid LZ4 frame must contain magic number (4 bytes), frame descriptor (at least 3 bytes), and EndMark
        // (4 bytes), assuming zero data blocks.
        guard data.count >= 11
            else { throw DataError.truncated }
        let reader = LittleEndianByteReader(data: data)
        // TODO: Switch between frame and block decoding modes?
        // TODO: Tests for data truncated at various places.
        // TODO: Test various advanced options of LZ4.

        // Magic number.
        // TODO: Skippable frames
        // TODO: Legacy frames
        guard reader.uint32() == 0x184D2204
            else { throw DataError.corrupted }

        // Frame Descriptor
        let flg = reader.byte()
        // Version number and reserved bit check.
        guard (flg & 0xC0) >> 6 == 1 && flg & 0x2 == 0
            else { throw DataError.corrupted }

        /// True, if blocks are independent and thus multi-threaded decoding is possible. Otherwise, blocks must be
        /// decoded in sequence.
        let independentBlocks = (flg & 0x20) >> 5 == 1
        /// True, if each data block is followed by a checksum for compressed data, which can be used to detect data
        /// corruption before decoding.
        let blockChecksumPresent = (flg & 0x10) >> 4 == 1
        /// True, if the size of uncompressed data is present after the flags.
        let contentSizePresent = (flg & 0x8) >> 3 == 1
        /// True, if the checksum for uncompressed data is present after the EndMark.
        let contentChecksumPresent = (flg & 0x4) >> 2 == 1
        /// True, if the dictionary ID field is present after the flags and content size.
        let dictIdPresent = flg & 1 == 1

        let bd = reader.byte()
        // Reserved bits check.
        guard bd & 0x8F == 0
            else { throw DataError.corrupted }
        // Since we don't do manual memory allocation, we don't need to decode the block maximum size from `bd`.

        let contentSize: Int?
        if contentSizePresent {
            // At this point valid LZ4 frame must have at least 13 bytes remaining for: content size (8 bytes), header
            // checksum (1 byte), and EndMark (4 bytes), assuming zero data blocks.
            // TODO: test truncated
            guard reader.bytesLeft >= 13
                else { throw DataError.truncated }
            // Since Data is indexed by the Int type, the maximum size of the uncompressed data that we can decode is
            // Int.max. However, LZ4 supports uncompressed data sizes up to UInt64.max, which is larger, so we check
            // for this possibility.
            let rawContentSize = reader.uint64()
            guard rawContentSize <= UInt64(truncatingIfNeeded: Int.max)
                else { throw DataError.unsupportedFeature }
            contentSize = Int(truncatingIfNeeded: rawContentSize)
        } else {
            contentSize = nil
        }

        guard !dictIdPresent
            else { throw DataError.unsupportedFeature }

        // Header doesn't include magic number.
        let headerData = data[data.startIndex + 4..<data.startIndex + 4 + 2 + (contentSizePresent ? 8 : 0) + (dictIdPresent ? 4 : 0)]
        let headerChecksum = XxHash32.hash(data: headerData)
        guard UInt8(truncatingIfNeeded: (headerChecksum >> 8) & 0xFF) == reader.byte()
            else { throw DataError.corrupted }

        var out = Data()
        while true {
            /// Either the size of the block, or the EndMark.
            let blockMark = reader.uint32()
            // Check for the EndMark.
            if blockMark == 0 {
                break
            }
            // The highest bit indicates if the block is compressed.
            let compressed = blockMark & 0x80000000 == 0
            let blockSize = (blockMark & 0x7FFFFFFF).toInt()
            // TODO: "Block_Size shall never be larger than Block_Maximum_Size". Should we verify this condition?
            // TODO: Check how reference implementation reacts to violation of this condition (during decompression).

            // TODO: test truncated
            guard reader.bytesLeft >= blockSize + (blockChecksumPresent ? 4 : 0) + 4
                else { throw DataError.truncated }

            let blockData = data[reader.offset..<reader.offset + blockSize]
            reader.offset += blockSize
            guard !blockChecksumPresent || XxHash32.hash(data: blockData) == reader.uint32()
                else { throw DataError.corrupted }

            if compressed {
                out.append(try LZ4.processCompressedBlock(blockData))
            } else {
                out.append(blockData)
            }
        }
        if contentSizePresent {
            guard out.count == contentSize
                else { throw DataError.corrupted }
        }
        if contentChecksumPresent {
            // TODO: test truncated
            guard reader.bytesLeft >= 4
                else { throw DataError.truncated }
            guard XxHash32.hash(data: out) == reader.uint32()
                else { throw DataError.checksumMismatch([out]) }
        }
        return out
    }

    // TODO: Multi-frame decoding, similar to XZArchive.splitUnarchive or GzipArchive.multiUnarchive.

    private static func processCompressedBlock(_ data: Data) throws -> Data {
        fatalError("Not implemented yet")
    }

}
