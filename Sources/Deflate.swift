//
//  Deflate.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during deflate decompression.
 It may indicate that either the data is damaged or it might not be compressed with DEFLATE at all.

 - `wrongUncompressedBlockLengths`: `length` and `nlength` bytes of uncompressed block were not compatible.
 - `wrongBlockType`: unsupported block type (not 0, 1 or 2).
 - `wrongSymbol`: unsupported Huffman tree's symbol.
 - `symbolNotFound`: symbol from input data was not found in Huffman tree.
 */
public enum DeflateError: Error {
    /// Uncompressed block' `length` and `nlength` bytes were not compatible.
    case wrongUncompressedBlockLengths
    /// Unknown block type (not from 0 to 2).
    case wrongBlockType
    /// Decoded symbol was found in Huffman tree but is unknown.
    case wrongSymbol
    /// Symbol was not found in Huffman tree.
    case symbolNotFound
}

/// Provides function to decompress data, which were compressed with DEFLATE.
public class Deflate: DecompressionAlgorithm {

    private struct Constants {
        static let codeLengthOrders: [Int] =
            [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

        /// - Warning: Substract 257 from index!
        static let lengthBase: [Int] =
            [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35,
             43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]

        static let distanceBase: [Int] =
            [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
             257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
             8193, 12289, 16385, 24577]

        static let lengthCode: [Int] =
            [257, 258, 259, 260, 261, 262, 263, 264, 265, 265, 266, 266, 267, 267, 268, 268,
             269, 269, 269, 269, 270, 270, 270, 270, 271, 271, 271, 271, 272, 272, 272, 272,
             273, 273, 273, 273, 273, 273, 273, 273, 274, 274, 274, 274, 274, 274, 274, 274,
             275, 275, 275, 275, 275, 275, 275, 275, 276, 276, 276, 276, 276, 276, 276, 276,
             277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
             278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278,
             279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279,
             280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280,
             281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281,
             281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281,
             282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282,
             282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282,
             283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283,
             283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283,
             284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284,
             284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 285]
    }

    /**
        Decompresses `compressedData` with DEFLATE algortihm.

        If data passed is not actually compressed with DEFLATE, `DeflateError` will be thrown.

     - Parameter compressedData: Data compressed with DEFLATE.

     - Throws: `DeflateError` if unexpected byte (bit) sequence was encountered in `compressedData`.
        It may indicate that either the data is damaged or it might not be compressed with DEFLATE at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        return Data(bytes: try decompress(&pointerData))
    }

    static func decompress(_ pointerData: inout DataWithPointer) throws -> [UInt8] {
        /// An array for storing output data
        var out: [UInt8] = []

        while true {
            /// Is this a last block?
            let isLastBit = pointerData.bit()
            /// Type of the current block.
            let blockType = [UInt8](pointerData.bits(count: 2).reversed())

            if blockType == [0, 0] { // Uncompressed block.
                pointerData.skipUntilNextByte()
                /// Length of the uncompressed data.
                let length = pointerData.intFromBits(count: 16)
                /// 1-complement of the length.
                let nlength = pointerData.intFromBits(count: 16)
                // Check if lengths are OK (nlength should be a 1-complement of length).
                guard length & nlength == 0 else { throw DeflateError.wrongUncompressedBlockLengths }
                // Process uncompressed data into the output
                for _ in 0..<length {
                    out.append(pointerData.alignedByte())
                }
            } else if blockType == [1, 0] || blockType == [0, 1] {
                // Block with Huffman coding (either static or dynamic)

                // Declaration of Huffman trees which will be populated and used later.
                // There are two alphabets in use and each one needs a Huffman tree.

                /// Huffman tree for literal and length symbols/codes.
                var mainLiterals: HuffmanTree
                /// Huffman tree for backward distance symbols/codes.
                var mainDistances: HuffmanTree

                if blockType == [0, 1] { // Static Huffman
                    // In this case codes for literals and distances are fixed.
                    // Bootstraps for trees (first element in pair is code, second is number of bits).
                    let staticHuffmanBootstrap = [[0, 8], [144, 9], [256, 7], [280, 8], [288, -1]]
                    let staticHuffmanLengthsBootstrap = [[0, 5], [32, -1]]
                    // Initialize trees from these bootstraps.
                    mainLiterals = HuffmanTree(bootstrap: staticHuffmanBootstrap, &pointerData)
                    mainDistances = HuffmanTree(bootstrap: staticHuffmanLengthsBootstrap, &pointerData)
                } else { // Dynamic Huffman
                    // In this case there are Huffman codes for two alphabets in data right after block header.
                    // Each code defined by a sequence of code lengths (which are compressed themselves with Huffman).

                    /// Number of literals codes.
                    let literals = pointerData.intFromBits(count: 5) + 257
                    /// Number of distances codes.
                    let distances = pointerData.intFromBits(count: 5) + 1
                    /// Number of code lengths codes.
                    let codeLengthsLength = pointerData.intFromBits(count: 4) + 4

                    // Read code lengths codes.
                    // Moreover, they are stored in a very specific order, 
                    //  defined by HuffmanTree.Constants.codeLengthOrders.
                    var lengthsForOrder = Array(repeating: 0, count: 19)
                    for i in 0..<codeLengthsLength {
                        lengthsForOrder[Constants.codeLengthOrders[i]] = pointerData.intFromBits(count: 3)
                    }
                    /// Huffman tree for code lengths. Each code in the main alphabets is coded with this tree.
                    let dynamicCodes = HuffmanTree(lengthsToOrder: lengthsForOrder, &pointerData)

                    // Now we need to read codes (code lengths) for two main alphabets (trees).
                    var codeLengths: [Int] = []
                    var n = 0
                    while n < (literals + distances) {
                        // Finding next Huffman tree's symbol in data.
                        let symbol = dynamicCodes.findNextSymbol()
                        guard symbol != -1 else { throw DeflateError.symbolNotFound }

                        let count: Int
                        let what: Int
                        if symbol >= 0 && symbol <= 15 {
                            // It is a raw code length.
                            count = 1
                            what = symbol
                        } else if symbol == 16 {
                            // Copy previous code length 3 to 6 times.
                            // Next two bits show how many times we need to copy.
                            count = pointerData.intFromBits(count: 2) + 3
                            what = codeLengths.last!
                        } else if symbol == 17 {
                            // Repeat code length 0 for from 3 to 10 times.
                            // Next three bits show how many times we need to copy.
                            count = pointerData.intFromBits(count: 3) + 3
                            what = 0
                        } else if symbol == 18 {
                            // Repeat code length 0 for from 11 to 138 times.
                            // Next seven bits show how many times we need to do this.
                            count = pointerData.intFromBits(count: 7) + 11
                            what = 0
                        } else {
                            throw DeflateError.wrongSymbol
                        }
                        for _ in 0..<count {
                            codeLengths.append(what)
                        }
                        n += count
                    }
                    // We have read codeLengths for both trees at once.
                    // Now we need to split them and make corresponding trees.
                    mainLiterals = HuffmanTree(lengthsToOrder: Array(codeLengths[0..<literals]),
                                               &pointerData)
                    mainDistances = HuffmanTree(lengthsToOrder: Array(codeLengths[literals..<codeLengths.count]),
                                                &pointerData)
                }

                // Main loop of data decompression.
                while true {
                    // Read next symbol from data.
                    // It will be either literal symbol or a length of (previous) data we will need to copy.
                    let nextSymbol = mainLiterals.findNextSymbol()
                    guard nextSymbol != -1 else { throw DeflateError.symbolNotFound }

                    if nextSymbol >= 0 && nextSymbol <= 255 {
                        // It is a literal symbol so we add it straight to the output data.
                        out.append(nextSymbol.toUInt8())
                    } else if nextSymbol == 256 {
                        // It is a symbol indicating the end of data.
                        break
                    } else if nextSymbol >= 257 && nextSymbol <= 285 {
                        // It is a length symbol.
                        // Depending on the value of nextSymbol there might be additional bits in data,
                        // which we need to add to nextSymbol to get the full length.
                        let extraLength = (257 <= nextSymbol && nextSymbol <= 260) || nextSymbol == 285 ?
                            0 : (((nextSymbol - 257) >> 2) - 1)
                        // Actually, nextSymbol is not a starting value of length,
                        //  but an index for special array of starting values.
                        let length = Constants.lengthBase[nextSymbol - 257] +
                            pointerData.intFromBits(count: extraLength)

                        // Then we need to get distance code.
                        let distanceCode = mainDistances.findNextSymbol()
                        guard distanceCode != -1 else { throw DeflateError.symbolNotFound }
                        guard distanceCode >= 0 && distanceCode <= 29
                            else { throw DeflateError.wrongSymbol }

                        // Again, depending on the distanceCode's value there might be additional bits in data,
                        // which we need to combine with distanceCode to get the actual distance.
                        let extraDistance = distanceCode == 0 || distanceCode == 1 ? 0 : ((distanceCode >> 1) - 1)
                        // And yes, distanceCode is not a first part of distance but rather an index for special array.
                        let distance = Constants.distanceBase[distanceCode] +
                            pointerData.intFromBits(count: extraDistance)

                        // We should repeat last 'distance' amount of data.
                        // The amount of times we do this is round(length / distance).
                        // length actually indicates the amount of data we get from this nextSymbol.
                        let repeatCount: Int = length / distance
                        let count = out.count
                        for _ in 0..<repeatCount {
                            for i in count - distance..<count {
                                out.append(out[i])
                            }
                        }
                        // Now we deal with the remainings.
                        if length - distance * repeatCount == distance {
                            for i in out.count - distance..<out.count {
                                out.append(out[i])
                            }
                        } else {
                            for i in out.count - distance..<out.count + length - distance * (repeatCount + 1) {
                                out.append(out[i])
                            }
                        }
                    } else {
                        throw DeflateError.wrongSymbol
                    }
                }

            } else {
                throw DeflateError.wrongBlockType
            }

            // End the cycle if it was the last block.
            if isLastBit == 1 { break }
        }

        return out
    }

    /**
     Compresses `data` with DEFLATE algortihm.

     If during compression something goes wrong `DeflateError` will be thrown.

     - Note: Currently, SWCompression creates only one block for all data
     and the block can either be uncompressed or compressed with static Huffman encoding.
     Uncompressed block is created if amount of data provided is less than 3 bytes and
     static Huffman is used in all other cases.
     */
    public static func compress(data: Data) throws -> Data {
        let bytes = data.toArray(type: UInt8.self)

        if bytes.count < 3 {
            return Data(bytes: Deflate.createUncompressedBlock(bytes))
        }

        let bldCodes = Deflate.lengthEncode(bytes)

        // Let's count possible sizes according to statistics.

        // Uncompressed block size calculation is simple:
        let uncompBlockSize = 1 + 2 + 2 + bytes.count // Header, length, n-length and data.

        // Static Huffman size is more complicated...
        var bitsCount = 3 // Three bits for block's header.
        for (symbol, symbolCount) in bldCodes.stats.enumerated() {
            let codeSize: Int
            // There are extra bits for some codes.
            let extraBitsCount: Int
            switch symbol {
            case 0...143:
                codeSize = 8
                extraBitsCount = 0
            case 144...255:
                codeSize = 9
                extraBitsCount = 0
            case 256...279:
                codeSize = 7
                extraBitsCount = 256 <= symbol && symbol <= 260 ? 0 : (((symbol - 257) >> 2) - 1)
            case 280...285:
                codeSize = 8
                extraBitsCount = symbol == 285 ? 0 : (((symbol - 257) >> 2) - 1)
            case 286...315:
                codeSize = 5
                extraBitsCount = symbol == 286 || symbol == 287 ? 0 : (((symbol - 286) >> 1) - 1)
            default:
                throw DeflateError.symbolNotFound
            }
            bitsCount += (symbolCount * (codeSize + extraBitsCount))
        }
        let staticHuffmanBlockSize = bitsCount % 8 == 0 ? bitsCount / 8 : bitsCount / 8 + 1

        // Since `length` of uncompressed block is 16-bit integer,
        // there is a limitation on size of uncompressed block.
        // Falling back to static Huffman encoding in case of big uncompressed block is a band-aid solution.
        if uncompBlockSize <= staticHuffmanBlockSize && uncompBlockSize <= 65535 {
            // If according to our calculations static huffman will not make output smaller than input,
            // we fallback to creating uncompressed block.
            // In this case dynamic Huffman encoding can be efficient.
            // TODO: Implement dynamic Huffman code!
            return Data(bytes: Deflate.createUncompressedBlock(bytes))
        } else {
            return Data(bytes: try Deflate.encodeHuffmanBlock(bldCodes.codes))
        }
    }

    private static func createUncompressedBlock(_ bytes: [UInt8]) -> [UInt8] {
        let bitWriter = BitToByteWriter(bitOrder: .reversed)

        // Write block header.
        // Note: Only one block is supported for now.
        bitWriter.write(bit: 1)
        bitWriter.write(bits: [0, 0])

        // Before writing lengths we need to discard remaining bits in current byte.
        bitWriter.finish()

        // Write data's length.
        bitWriter.write(number: bytes.count, bitsCount: 16)
        // Write data's n-length.
        bitWriter.write(number: bytes.count ^ (1 << 16 - 1), bitsCount: 16)

        var out = bitWriter.buffer

        // Write actual data.
        for byte in bytes {
            out.append(byte)
        }

        return out
    }

    private static func encodeHuffmanBlock(_ bldCodes: [BLDCode]) throws -> [UInt8] {
        var bitWriter = BitToByteWriter(bitOrder: .reversed)

        // Write block header.
        // Note: For now it is only static huffman blocks.
        // Note: Only one block is supported for now.
        bitWriter.write(bit: 1)
        bitWriter.write(bits: [1, 0])

        /// Empty DWP object for creating Huffman trees.
        var pointerData = DataWithPointer(data: Data(), bitOrder: .reversed)

        // Constructing Huffman trees for the case of block with preset alphabets.
        // In this case codes for literals and distances are fixed.
        // Bootstraps for trees (first element in pair is code, second is number of bits).
        let staticHuffmanBootstrap = [[0, 8], [144, 9], [256, 7], [280, 8], [288, -1]]
        let staticHuffmanLengthsBootstrap = [[0, 5], [32, -1]]
        /// Huffman tree for literal and length symbols/codes.
        let mainLiterals = HuffmanTree(bootstrap: staticHuffmanBootstrap, &pointerData, true)
        /// Huffman tree for backward distance symbols/codes.
        let mainDistances = HuffmanTree(bootstrap: staticHuffmanLengthsBootstrap, &pointerData, true)

        for code in bldCodes {
            switch code {
            case .byte(let byte):
                try mainLiterals.code(symbol: byte.toInt(), &bitWriter, DeflateError.symbolNotFound)
            case .lengthDistance(let ld):
                try mainLiterals.code(symbol: ld.lengthSymbol, &bitWriter, DeflateError.symbolNotFound)
                bitWriter.write(number: ld.lengthExtraBits, bitsCount: ld.lengthExtraBitsCount)

                try mainDistances.code(symbol: ld.distanceSymbol, &bitWriter, DeflateError.symbolNotFound)
                bitWriter.write(number: ld.distanceExtraBits, bitsCount: ld.distanceExtraBitsCount)
            }
        }

        // End data symbol.
        try mainLiterals.code(symbol: 256, &bitWriter, DeflateError.symbolNotFound)
        bitWriter.finish()

        return bitWriter.buffer
    }

    private struct LengthDistance {

        let length: Int
        let lengthSymbol: Int
        let lengthExtraBits: Int
        let lengthExtraBitsCount: Int

        let distance: Int
        let distanceSymbol: Int
        let distanceExtraBits: Int
        let distanceExtraBitsCount: Int

        init(_ length: Int, _ distance: Int) {
            self.length = length
            let lengthSymbol = Constants.lengthCode[length - 3]
            self.lengthSymbol = lengthSymbol
            self.lengthExtraBits = length - Constants.lengthBase[lengthSymbol - 257]
            self.lengthExtraBitsCount = (257 <= lengthSymbol && lengthSymbol <= 260) || lengthSymbol == 285 ?
                0 : (((lengthSymbol - 257) >> 2) - 1)

            self.distance = distance
            let distanceSymbol = ((Constants.distanceBase.index { $0 > distance }) ?? 30) - 1
            self.distanceSymbol = distanceSymbol
            self.distanceExtraBits = distance - Constants.distanceBase[distanceSymbol]
            self.distanceExtraBitsCount = distanceSymbol == 0 || distanceSymbol == 1 ? 0 : ((distanceSymbol >> 1) - 1)
        }

    }

    private enum BLDCode: CustomStringConvertible {
        case byte(UInt8)
        case lengthDistance(LengthDistance)

        var description: String {
            switch self {
            case .byte(let byte):
                return "raw symbol: \(byte)"
            case .lengthDistance(let ld):
                return "length: \(ld.length), length symbol: \(ld.lengthSymbol), " +
                    "distance: \(ld.distance), distance symbol: \(ld.distanceSymbol)"
            }
        }
    }

    private static func lengthEncode(_ rawBytes: [UInt8]) -> (codes: [BLDCode], stats: [Int]) {
        precondition(rawBytes.count >= 3, "Too small array!")

        var buffer: [BLDCode] = []
        var inputIndex = 0
        /// Keys --- three-byte crc32, values --- positions in `rawBytes`.
        var dictionary = [UInt32: Int]()

        var stats = Array(repeating: 0, count: 316)

        while inputIndex < rawBytes.count {
            let byte = rawBytes[inputIndex]

            // For last two bytes there certainly will be no match.
            // Moreover, `threeByteCrc` cannot be computed, so we need to put them in as `.byte`s.
            // To simplify code we check for this case explicitly.
            if inputIndex >= rawBytes.count - 2 {
                buffer.append(BLDCode.byte(byte))
                stats[byte.toInt()] += 1
                if inputIndex != rawBytes.count - 1 { // For the case of two remaining bytes.
                    buffer.append(BLDCode.byte(rawBytes[inputIndex + 1]))
                    stats[rawBytes[inputIndex + 1].toInt()] += 1
                }
                break
            }

            let threeByteCrc = CheckSums.crc32([rawBytes[inputIndex],
                                                rawBytes[inputIndex + 1],
                                                rawBytes[inputIndex + 2]])

            if let matchStartIndex = dictionary[threeByteCrc] {
                // We need to update position of this match to keep distances as small as possible.
                dictionary[threeByteCrc] = inputIndex

                /// - Note: Minimum match length equals to three.
                var matchLength = 3
                /// Cyclic index which is used to compare bytes in match and in input.
                var repeatIndex = matchStartIndex + matchLength

                /// - Note: Maximum allowed distance equals to 32768.
                let distance = inputIndex - matchStartIndex

                // Again, the distance cannot be greater than 32768.
                if distance <= 32768 {
                    while inputIndex + matchLength < rawBytes.count &&
                        rawBytes[inputIndex + matchLength] == rawBytes[repeatIndex] && matchLength < 258 {
                        matchLength += 1
                        repeatIndex += 1
                        if repeatIndex > inputIndex {
                            repeatIndex = matchStartIndex + 1
                        }
                    }
                    let ld = LengthDistance(matchLength, distance)
                    buffer.append(BLDCode.lengthDistance(ld))
                    stats[ld.lengthSymbol] += 1
                    stats[286 + ld.distanceSymbol] += 1
                    inputIndex += matchLength
                } else {
                    buffer.append(BLDCode.byte(byte))
                    stats[byte.toInt()] += 1
                    inputIndex += 1
                }
            } else {
                // We need to remember where we met this three-byte sequence.
                dictionary[threeByteCrc] = inputIndex

                buffer.append(BLDCode.byte(byte))
                stats[byte.toInt()] += 1
                inputIndex += 1
            }
            // TODO: Add limitation for dictionary size.
        }

        stats[256] += 1

        return (buffer, stats)
    }

}
