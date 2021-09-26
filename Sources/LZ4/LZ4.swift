// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

public enum LZ4: DecompressionAlgorithm {

    public static func decompress(data: Data) throws -> Data {
        return try LZ4.decompress(data: data, dictionary: nil)
    }

    public static func decompress(data: Data, dictionary: Data?, dictionaryID: Int? = nil) throws -> Data {
        if let dictID = dictionaryID {
            precondition(dictID < UInt32.max, "dictionaryID is too big.")
        }
        // Valid LZ4 frame must contain at least a magic number (4 bytes).
        guard data.count >= 4
            else { throw DataError.truncated }
        // TODO: Switch between frame and block decoding modes?
        // TODO: Tests for data truncated at various places.

        // Magic number.
        let magic = data[data.startIndex..<data.startIndex + 4].withUnsafeBytes { $0.bindMemory(to: UInt32.self)[0] }
        switch magic {
        case 0x184D2204:
            return try LZ4.process(frame: data[(data.startIndex + 4)...], dictionary, dictionaryID)
        case 0x184D2A50...0x184D2A5F:
            let frameSize = try process(skippableFrame: data[(data.startIndex + 4)...])
            return try LZ4.decompress(data: data[(data.startIndex + 4 + frameSize)...])
        case 0x184C2102:
            return try LZ4.process(legacyFrame: data[(data.startIndex + 4)...])
        default:
            throw DataError.corrupted
        }
    }

    private static func process(skippableFrame data: Data) throws -> Data.Index {
        guard data.count >= 4
            else { throw DataError.truncated }
        let size = data[data.startIndex..<data.startIndex + 4].withUnsafeBytes { $0.bindMemory(to: UInt32.self)[0] }.toInt()
        guard data.count >= size + 4
            else { throw DataError.truncated }
        return size + 4
    }

    private static func process(legacyFrame data: Data) throws -> Data {
        let reader = LittleEndianByteReader(data: data)
        var out = Data()
        // The end of a frame is determined is either by end-of-file or by encountering a valid frame magic number.
        while !reader.isFinished {
            // TODO: test truncated
            guard reader.bytesLeft >= 4
                else { throw DataError.truncated }
            let rawBlockSize = reader.uint32()
            // TODO: Can legacy and non-legacy frames can be contacenated (check reference implementation)?
            if rawBlockSize == 0x184D2204 || rawBlockSize == 0x184C2102 || 0x184D2A50...0x184D2A5F ~= rawBlockSize {
                break
            }
            // Detects overflow issues on 32-bit platforms.
            guard rawBlockSize <= UInt32(truncatingIfNeeded: Int.max)
                else { throw DataError.unsupportedFeature }
            let blockSize = Int(truncatingIfNeeded: rawBlockSize)

            // TODO: test truncated
            guard reader.bytesLeft >= blockSize
                else { throw DataError.truncated }

            let blockData = data[reader.offset..<reader.offset + blockSize]
            reader.offset += blockSize

            out.append(try LZ4.process(block: blockData))
        }
        return out
    }

    private static func process(frame data: Data, _ dictionary: Data?, _ extDictId: Int?) throws -> Data {
        // Valid LZ4 frame must contain frame descriptor (at least 3 bytes) and EndMark (4 bytes), assuming no data blocks.
        guard data.count >= 7
            else { throw DataError.truncated }
        let reader = LittleEndianByteReader(data: data)

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

        let dictId: Int?
        if dictIdPresent {
            // At this point valid LZ4 frame must have at least 9 bytes remaining for: dictionary ID (4 bytes), header
            // checksum (1 byte), and EndMark (4 bytes), assuming zero data blocks.
            // TODO: test truncated
            guard reader.bytesLeft >= 9
                else { throw DataError.truncated }

            let rawDictID = reader.uint32()
            // Detects overflow issues on 32-bit platforms.
            guard rawDictID <= UInt32(truncatingIfNeeded: Int.max)
                else { throw DataError.unsupportedFeature }
            dictId = Int(truncatingIfNeeded: rawDictID)
        } else {
            dictId = nil
        }

        if let extDictId = extDictId, let dictId = dictId {
            // If dictionary ID is present in the frame, and passed as an argument, then they must be equal.
            guard extDictId == dictId
                else { throw DataError.corrupted }
        }

        let headerData = data[data.startIndex..<data.startIndex + 2 + (contentSizePresent ? 8 : 0) + (dictIdPresent ? 4 : 0)]
        let headerChecksum = XxHash32.hash(data: headerData)
        guard UInt8(truncatingIfNeeded: (headerChecksum >> 8) & 0xFF) == reader.byte()
            else { throw DataError.corrupted }

        var out = Data()
        while true {
            // TODO: test truncated
            guard reader.bytesLeft >= 4
                else { throw DataError.truncated }
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
                if independentBlocks {
                    out.append(try LZ4.process(block: blockData, dictionary))
                } else {
                    if out.isEmpty, let dictionary = dictionary {
                        out.append(try LZ4.process(block: blockData,
                                                   dictionary[max(dictionary.endIndex - 64 * 1024, 0)...]))
                    } else {
                        out.append(try LZ4.process(block: blockData,
                                                   out[max(out.endIndex - 64 * 1024, 0)...]))
                    }
                }
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
    // TODO: Public method for querying dictionary ID.

    private static func process(block data: Data, _ dict: Data? = nil) throws -> Data {
        let reader = LittleEndianByteReader(data: data)
        var out = dict ?? Data()

        // These two variables used in checking end of block restrictions.
        var sequenceCount = 0
        var lastMatchStartIndex = -1

        while true {
            sequenceCount += 1
            // TODO: test truncated
            guard data.endIndex - reader.offset > 1
                else { throw DataError.truncated }
            let token = reader.byte()

            var literalCount = (token >> 4).toInt()
            if literalCount == 15 {
                while true {
                    // TODO: test truncated
                    guard data.endIndex - reader.offset > 1
                        else { throw DataError.truncated }
                    let byte = reader.byte()
                    // There is no size limit on the literal count, so we need to check that it remains within Int range
                    // (similar to content size considerations).
                    let (newLiteralCount, overflow) = literalCount.addingReportingOverflow(byte.toInt())
                    guard !overflow
                        else { throw DataError.unsupportedFeature }
                    literalCount = newLiteralCount
                    if byte != 255 {
                        break
                    }
                }
            }
            // TODO: test truncated
            guard data.endIndex - reader.offset >= literalCount
                else { throw DataError.truncated }
            out.append(contentsOf: reader.bytes(count: literalCount))

            // The last sequence contains only literals.
            if reader.isFinished {
                // End of block restrictions.
                guard literalCount >= 5 || sequenceCount == 1
                    else { throw DataError.corrupted }
                guard out.endIndex - lastMatchStartIndex >= 12 || lastMatchStartIndex == -1
                    else { throw DataError.corrupted }
                break
            }

            // TODO: test truncated
            guard data.endIndex - reader.offset > 2
                else { throw DataError.truncated }
            let offset = reader.uint16().toInt()
            // The value of 0 is not valid.
            guard offset > 0 && offset <= out.endIndex
                else { throw DataError.corrupted }

            var matchLength = 4 + (token & 0xF).toInt()
            if matchLength == 19 {
                while true {
                    // TODO: test truncated
                    guard data.endIndex - reader.offset > 1
                        else { throw DataError.truncated }
                    let byte = reader.byte()
                    // Again, there is no size limit on the match length, so we need to check that it remains within Int
                    // range.
                    let (newMatchLength, overflow) = matchLength.addingReportingOverflow(byte.toInt())
                    guard !overflow
                        else { throw DataError.unsupportedFeature }
                    matchLength = newMatchLength
                    if byte != 255 {
                        break
                    }
                }
            }

            let matchStartIndex = out.endIndex - offset
            for i in 0..<matchLength {
                out.append(out[matchStartIndex + i])
            }
            lastMatchStartIndex = matchStartIndex
        }

        if let dict = dict {
            return out[dict.endIndex...]
        }
        return out
    }

}
