// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension LZ4: CompressionAlgorithm {

    public static func compress(data: Data) -> Data {
        return LZ4.compress(data: data, independentBlocks: true, blockChecksums: false, contentChecksum: true,
                            contentSize: false, blockSize: 4 * 1024 * 1024, dictionary: nil, dictionaryID: nil)
    }

    public static func compress(data: Data, independentBlocks: Bool, blockChecksums: Bool,
                                 contentChecksum: Bool, contentSize: Bool, blockSize: Int,
                                 dictionary: Data?, dictionaryID: UInt32? = nil) -> Data {
        var out = [UInt8]()

        // Magic number.
        out.append(contentsOf: [0x04, 0x22, 0x4D, 0x18])

        // FLG byte.
        out.append(0b0100_0000 |
                   (independentBlocks ? 0x20 : 0) |
                   (blockChecksums ? 0x10 : 0) |
                   (contentSize ? 0x8 : 0) |
                   (contentChecksum ? 0x4 : 0) |
                   (dictionaryID != nil ? 0x1 : 0))

        // BD byte.
        let bd: UInt8
        let maxBlockSize: Int
        if blockSize <= 64 * 1024 {
            maxBlockSize = 64 * 1024
            bd = 0x40
        } else if blockSize <= 256 * 1024 {
            maxBlockSize = 256 * 1024
            bd = 0x50
        } else if blockSize <= 1024 * 1024 {
            maxBlockSize = 1024 * 1024
            bd = 0x60
        } else {
            // Reference implementation sets maximum block size to 4 MB even if the requested block size is bigger.
            maxBlockSize = 4 * 1024 * 1024
            bd = 0x70
        }
        out.append(bd)

        if contentSize {
            let size = data.count
            for i in 0..<8 {
                out.append(UInt8(truncatingIfNeeded: (size & (0xFF << (i * 8))) >> (i * 8)))
            }
        }

        if let dictionaryID = dictionaryID {
            for i: UInt32 in 0..<4 {
                out.append(UInt8(truncatingIfNeeded: (dictionaryID & (0xFF << (i * 8))) >> (i * 8)))
            }
        }

        // Header checksum.
        let headerChecksum = XxHash32.hash(data: Data(out[4...]))
        out.append(UInt8(truncatingIfNeeded: (headerChecksum >> 8) & 0xFF))

        var dict = dictionary
        for i in stride(from: data.startIndex, to: data.endIndex, by: blockSize) {
            // TODO: Which block size should we use here: the arbitrary requested by the user, or the maxBlockSize?
            let blockData = data[i..<min(i + blockSize, data.endIndex)]
            let compressedBlock = LZ4.compress(block: blockData, dict)
            if !independentBlocks {
                dict = blockData[max(blockData.endIndex - 64 * 1024, 0)...]
            }

            if compressedBlock.count >= blockData.count { // TODO: > or >=? (right now >= to make trivial impl for compress(block:))
                // In this case the data is non-compressible, so we write the block as uncompressed.
                if blockData.count > 0x7FFFFFFF {
                    // TODO: In this case we cannot properly store uncompressed block, since either the highest bit of
                    // TODO: 4-bytes is already taken, or the block size is to big to fit into 4-bytes.
                    fatalError("Patalogical size of non-compressible block.")
                }
                let blockSize = (0x80000000 as UInt32) | UInt32(truncatingIfNeeded: blockData.count)
                for i: UInt32 in 0..<4 {
                    out.append(UInt8(truncatingIfNeeded: (blockSize & (0xFF << (i * 8))) >> (i * 8)))
                }
                out.append(contentsOf: blockData)
            } else {
                if compressedBlock.count > 0x7FFFFFFF {
                    // TODO: In this case we cannot properly store uncompressed block, since either the highest bit of
                    // TODO: 4-bytes is already taken, or the block size is to big to fit into 4-bytes.
                    fatalError("Patalogical size of compressed block.")
                }
                let blockSize = UInt32(truncatingIfNeeded: compressedBlock.count)
                for i:UInt32 in 0..<4 {
                    out.append(UInt8(truncatingIfNeeded: (blockSize & (0xFF << (i * 8))) >> (i * 8)))
                }
                out.append(contentsOf: compressedBlock)
            }

            if blockChecksums {
                let blockChecksum = XxHash32.hash(data: Data(compressedBlock))
                for i: UInt32 in 0..<4 {
                    out.append(UInt8(truncatingIfNeeded: (blockChecksum & (0xFF << (i * 8))) >> (i * 8)))
                }
            }
        }

        // EndMark.
        out.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Content checksum.
        if contentChecksum {
            let hash = XxHash32.hash(data: data)
            for i: UInt32 in 0..<4 {
                out.append(UInt8(truncatingIfNeeded: (hash & (0xFF << (i * 8))) >> (i * 8)))
            }
        }

        return Data(out)
    }

    private static func compress(block: Data, _ dict: Data?) -> [UInt8] {
        // TODO:
        return block.withUnsafeBytes { $0.map { $0 } }
    }

}
