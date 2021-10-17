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
                                 contentChecksum: Bool, contentSize: Bool, blockSize: Int = 4 * 1024 * 1024,
                                 dictionary: Data? = nil, dictionaryID: UInt32? = nil) -> Data {
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

        // TODO: Maybe we can use Data() instead of optional?
        var dict: Data?
        if let dictionary = dictionary {
            // Provided dictionary can be smaller than the standard size of 64 KB.
            dict = dictionary[max(dictionary.endIndex - 64 * 1024, dictionary.startIndex)...]
        } else {
            dict = nil
        }

        for i in stride(from: data.startIndex, to: data.endIndex, by: blockSize) {
            // TODO: Which block size should we use here: the arbitrary (requested by the user) or the maxBlockSize?
            let blockData = data[i..<min(i + blockSize, data.endIndex)]
            let compressedBlock = LZ4.compress(block: blockData, dict)
            if !independentBlocks {
                // If the blocks are dependent then we need to update the dictionary with the uncompressed data
                // from the current block.
                // TODO: Probably fails for dependent blocks with block size less than 64 KB.
                dict = blockData[max(blockData.endIndex - 64 * 1024, blockData.startIndex)...]
            }

            if compressedBlock.count > blockData.count {
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

                if blockChecksums {
                    let blockChecksum = XxHash32.hash(data: blockData)
                    for i: UInt32 in 0..<4 {
                        out.append(UInt8(truncatingIfNeeded: (blockChecksum & (0xFF << (i * 8))) >> (i * 8)))
                    }
                }
            } else {
                if compressedBlock.count > 0x7FFFFFFF {
                    // TODO: In this case we cannot properly store uncompressed block, since either the highest bit of
                    // TODO: 4-bytes is already taken, or the block size is to big to fit into 4-bytes.
                    fatalError("Patalogical size of compressed block.")
                }
                let blockSize = UInt32(truncatingIfNeeded: compressedBlock.count)
                for i: UInt32 in 0..<4 {
                    out.append(UInt8(truncatingIfNeeded: (blockSize & (0xFF << (i * 8))) >> (i * 8)))
                }
                out.append(contentsOf: compressedBlock)

                if blockChecksums {
                    let blockChecksum = XxHash32.hash(data: Data(compressedBlock))
                    for i: UInt32 in 0..<4 {
                        out.append(UInt8(truncatingIfNeeded: (blockChecksum & (0xFF << (i * 8))) >> (i * 8)))
                    }
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
        var out = [UInt8]()

        var blockBytes = dict?.withUnsafeBytes { $0.map { $0 } } ?? [UInt8]()
        var matchStorage = LZ4.populateMatchStorage(blockBytes)
        var i = blockBytes.endIndex
        block.withUnsafeBytes { $0.forEach { blockBytes.append($0) } }

        /// Literals of the currently constructed sequence.
        /// If the array isn't empty this indicates that there is an in-progress sequence.
        var currentLiterals = [UInt8]()

        // Match searching algorithm is mostly the same as the one that we use for Deflate. This algorithm prioritizes
        // the closest mathches (minimizes the distance). However, this is not important for LZ4, so in the future we
        // may investigate the posibility of removing this restriction, which may improve compression ratio (though,
        // we need to be careful to not to decrease compression speed disproportionally).
        // TODO: Maybe we should update match storage inside match-length-loop as well?

        // The last five bytes must be encoded as literals AND the last match must end before them. Non-minimal matches
        // are checked for this condition in the match-searching while-loop, but minmatches (4-bytes long) are verified
        // here (hence -9).
        while i < blockBytes.endIndex - 9 {
            let matchCrc = CheckSums.crc32(Data(blockBytes[i..<i + 4]))
            guard let matchStartIndex = matchStorage[matchCrc] else {
                // No match found.
                // We need to save where we met this four-byte sequence.
                matchStorage[matchCrc] = i
                currentLiterals.append(blockBytes[i])
                i += 1
                continue
            }
            // We need to update position of this match to keep distances as small as possible.
            matchStorage[matchCrc] = i

            // Minimum match length equals to four.
            var matchLength = 4
            // The index which points to the match from the past bytes. We use it to compare previous and current matches.
            var matchIndex = matchStartIndex + matchLength
            let distance = i - matchStartIndex
            // Maximum allowed distance equals to 65535.
            guard distance <= 65535 else {
                currentLiterals.append(blockBytes[i])
                i += 1
                continue
            }

            // TODO: While theoretically match length is not limited, we still have a practical limit of Int.max.
            // We exclude the last 5 bytes from the potential match since we need them for the separate
            // end-of-block sequence which contains only literals.
            while i + matchLength < blockBytes.endIndex - 5 && blockBytes[i + matchLength] == blockBytes[matchIndex] {
                matchLength += 1
                matchIndex += 1
            }

            if blockBytes.endIndex - distance < 12 {
                // The last match must start at least 12 bytes before the end of block.
                break
            }

            // Writing a sequence.
            // We start by constructing a token.
            var token = UInt8(truncatingIfNeeded: min(15, currentLiterals.count)) << 4
            token |= UInt8(truncatingIfNeeded: min(15, matchLength - 4))
            out.append(token)
            // Then we output additional bytes of the literals count.
            var literalsCount = currentLiterals.count - 15
            while literalsCount >= 0 {
                // TODO: Maybe this can be simplified with some fancy math expression.
                if literalsCount > 255 {
                    out.append(255)
                } else {
                    out.append(UInt8(truncatingIfNeeded: literalsCount))
                }
                literalsCount -= 255
            }
            for literal in currentLiterals {
                out.append(literal)
            }
            // Next we write the distance ("offset" in LZ4 terms) as little-endian UInt16 number.
            out.append(UInt8(truncatingIfNeeded: distance & 0xFF))
            out.append(UInt8(truncatingIfNeeded: (distance >> 8) & 0xFF))
            // Finally, we output match length in the same as we did for literals count.
            // But before that we need to skip the entire match in the input.
            i += matchLength
            matchLength -= 19 // 4 (min match length) + 15 (token value)
            while matchLength >= 0 {
                // TODO: Maybe this can be simplified with some fancy math expression.
                if matchLength > 255 {
                    out.append(255)
                } else {
                    out.append(UInt8(truncatingIfNeeded: matchLength))
                }
                matchLength -= 255
            }
            currentLiterals = [UInt8]()
        }

        // The last 5 bytes should be processed as literals. They will be either included in the unfinished sequence,
        // or they will form a new sequence. This also covers the case when the size of input is less than 5 bytes.
        if blockBytes.endIndex - i >= 5 {
            while i < blockBytes.endIndex {
                currentLiterals.append(blockBytes[i])
                i += 1
            }
        }

        // The block must end with a sequence that contains only literals, though the length of this sequence depends
        // on various circumstances.
        assert(currentLiterals.count > 0)
        out.append(UInt8(truncatingIfNeeded: min(15, currentLiterals.count)) << 4)
        var literalsCount = currentLiterals.count - 15
        while literalsCount >= 0 {
            // TODO: Maybe this can be simplified with some fancy math expression.
            if literalsCount > 255 {
                out.append(255)
            } else {
                out.append(UInt8(truncatingIfNeeded: literalsCount))
            }
            literalsCount -= 255
        }
        for literal in currentLiterals {
            out.append(literal)
        }

        return out
    }

    private static func populateMatchStorage(_ dict: [UInt8]) -> [UInt32: Int] {
        guard !dict.isEmpty
            else { return [:] }
        var matchStorage = [UInt32: Int]()
        for i in dict.startIndex..<dict.endIndex - 4 {
            let matchCrc = CheckSums.crc32(Data(dict[i..<i + 4]))
            matchStorage[matchCrc] = i
        }
        return matchStorage
    }

}
