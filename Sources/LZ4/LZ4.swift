// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

public enum LZ4: DecompressionAlgorithm {

    public static func decompress(data: Data) throws -> Data {
        let reader = LittleEndianByteReader(data: data)
        // TODO: Switch between frame and block decoding modes?
        // TODO: Small/empty data size check + Tests! (bytesLeft >= 4 + 3 + 4?)
        // TODO: Test various advanced options of LZ4.

        // Magic number.
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
            // Since Data is indexed by Int type, the maximum size of the uncompressed data that we can decode is
            // Int.max. However, LZ4 supports uncompressed data sizes up to UInt64.max, which is larger, so we check
            // for this possibility.
            let rawContentSize = reader.uint64()
            guard rawContentSize <= UInt64(truncatingIfNeeded: Int.max)
                else { throw DataError.unsupportedFeature }
            contentSize = Int(truncatingIfNeeded: rawContentSize)
        }

        // TODO: Support custom dictionaries.
        guard !dictIdPresent
            else { throw DataError.unsupportedFeature }
        // let dictId: Int?
        // if dictIdPresent {
        //     assert(Int.bitWidth > 32) // TODO: We need to properly support 32-bit platforms.
        //     dictId = Int(truncatingIfNeeded: reader.uint32())
        // }

        let headerData = data[data.startIndex..<data.startIndex + 2 + (contentSizePresent ? 8 : 0) + (dictIdPresent ? 4 : 0)]
        let headerChecksum = XxHash32.hash(data: headerData)
        guard UInt8(truncatingIfNeeded: (headerChecksum >> 8) & 0xFF) == reader.byte()
            else { throw DataError.corrupted }

        // TODO: Data Blocks
        var out = Data()
        while true {
            out.append(try LZ4.processBlock(reader))
            guard !reader.isFinished
                else { throw DataError.truncated }
            // Check for the EndMark.
            if reader.uint32() == 0 {
                break
            } else {
                reader.offset -= 4
            }
        }
        // TODO: Checksum
        return out
    }

    // TODO: Multi-frame decoding (similar to XZArchive.splitUnarchive).
    // TODO: Multi-thread decoding of blocks if they are independent.

    private static func processBlock(_ reader: LittleEndianByteReader) throws -> Data {
        fatalError("Not implemented yet")
    }

}
