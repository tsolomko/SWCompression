//
//  Deflate.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

// TODO: Rename HuffmanTableError to HuffmanTreeError.
/**
 Error happened during deflate decompression. 
 It may indicate that either the data is damaged or it might not be compressed with DEFLATE at all.
 
 - `WrongBlockLengths`: `length` and `nlength` bytes of uncompressed block were not compatible.
 - `HuffmanTableError`: either error occured while parsing bytes related to Huffman coding or
    problem is happened during various calculations of Huffman coding.
 - `UnknownBlockType`: block type was 3, which is unknown block type.
 */
public enum DeflateError: Error {
    /// Uncompressed block' `length` and `nlength` bytes were not compatible.
    case WrongBlockLengths
    /// Either error occured while parsing bytes related to Huffman coding or problem is happened during various calculations of Huffman coding.
    case HuffmanTableError
    /// Block type was 3, which is unknown block type.
    case UnknownBlockType
}

/// Provides function to decompress data, which were compressed with DEFLATE
public class Deflate: DecompressionAlgorithm {

    /**
        Decompresses `compressedData` with DEFLATE algortihm.

        If data passed is not actually compressed with DEFLATE, `DeflateError` will be thrown.

     - Parameter compressedData: Data compressed with DEFLATE.
     
     - Throws: `DeflateError` if unexpected byte (bit) sequence was encountered in `compressedData`. 
        It may indicate that either the data is damaged or it might not be compressed with DEFLATE at all.

     - Returns: Decompressed data.
     */
    public static func decompress(compressedData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        return try decompress(pointerData: pointerData)
    }

    static func decompress(pointerData: DataWithPointer) throws -> Data {
        /// Object for storing output data
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
                // TODO: Rename WrongBlockLengths to WrongUncompressedBlockLengths (or something else)
                guard length & nlength == 0 else { throw DeflateError.WrongBlockLengths }
                // Process uncompressed data into the output
                // TODO: Replace precondition with guard and error throwing.
                precondition(pointerData.bitMask == 1, "Misaligned byte.")
                var ind = out.count
                out.append(contentsOf: Array(repeating: 0, count: length))
                for _ in 0..<length {
                    out[ind] = pointerData.alignedByte()
                    ind += 1
                }
            } else if blockType == [1, 0] || blockType == [0, 1] {
                // Block with Huffman coding (either static or dynamic)

                // Declaration of Huffman tables which will be populated and used later.
                // There are two alphabets in use and each one needs a Huffman table.

                /// Huffman table for literal bytes.
                var mainLiterals: HuffmanTree
                /// Huffman table for bytes alphabet and alphabet of pairs (length, backward distance).
                var mainDistances: HuffmanTree

                if blockType == [0, 1] { // Static Huffman
                    // In this case codes for literals and distances are fixed.
                    // Bootstraps for tables (first element in pair is code, second is number of bits).
                    let staticHuffmanBootstrap = [[0, 8], [144, 9], [256, 7], [280, 8], [288, -1]]
                    let staticHuffmanLengthsBootstrap = [[0, 5], [32, -1]]
                    // Initialize tables from these bootstraps.
                    mainLiterals = HuffmanTree(bootstrap: staticHuffmanBootstrap)
                    mainDistances = HuffmanTree(bootstrap: staticHuffmanLengthsBootstrap)
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
                    // Moreover, they are stored in a very specific order (defined by HuffmanTree.Constants.codeLengthOrders).
                    var lengthsForOrder = Array(repeating: 0, count: 19)
                    for i in 0..<codeLengthsLength {
                        lengthsForOrder[HuffmanTree.Constants.codeLengthOrders[i]] = pointerData.intFromBits(count: 3)
                    }
                    /// Huffman table for code lengths. Each code in the main alphabets is coded with this table.
                    let dynamicCodes = HuffmanTree(lengthsToOrder: lengthsForOrder)

                    // Now we need to read codes (code lengths) for two main alphabets (tables).
                    var codeLengths: [Int] = []
                    var n = 0
                    while n < (literals + distances) {
                        // Finding next Huffman table's symbol in data.
                        let symbol = dynamicCodes.findNextSymbol(in: pointerData)
                        guard symbol != -1 else { throw DeflateError.HuffmanTableError }

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
                            // Repeat code length 0 for 3 to 10 times.
                            // Next three bits show how many times we need to copy.
                            count = pointerData.intFromBits(count: 3) + 3
                            what = 0
                        } else if symbol == 18 {
                            // Put code length 0 in table 11 to 138 times.
                            // Next seven bits show how many times we need to do this.
                            count = pointerData.intFromBits(count: 7) + 11
                            what = 0
                        } else {
                            throw DeflateError.HuffmanTableError
                        }
                        codeLengths.append(contentsOf: Array(repeating: what, count: count))
                        n += count
                    }
                    // We have read codeLengths for both tables at once.
                    // Now we need to split them and make corresponding tables.
                    mainLiterals = HuffmanTree(lengthsToOrder: Array(codeLengths[0..<literals]))
                    mainDistances = HuffmanTree(lengthsToOrder: Array(codeLengths[literals..<codeLengths.count]))
                }

                // Main loop of data decompression.
                while true {
                    // Read next symbol from data.
                    // It will be either literal symbol or a length of (previous) data we will need to copy.
                    let nextSymbol = mainLiterals.findNextSymbol(in: pointerData)
                    guard nextSymbol != -1 else { throw DeflateError.HuffmanTableError }

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
                        // Actually, nextSymbol is not a starting value of length but an index for special array of starting values.
                        let length = HuffmanTree.Constants.lengthBase[nextSymbol - 257] +
                            pointerData.intFromBits(count: extraLength)

                        // Then we need to get distance code.
                        let distanceCode = mainDistances.findNextSymbol(in: pointerData)
                        guard distanceCode != -1 else { throw DeflateError.HuffmanTableError }

                        if distanceCode >= 0 && distanceCode <= 29 {
                            // Again, depending on the distanceCode's value there might be additional bits in data,
                            // which we need to combine with distanceCode to get the actual distance.
                            let extraDistance = distanceCode == 0 || distanceCode == 1 ? 0 : ((distanceCode >> 1) - 1)
                            // And yes, distanceCode is not a first part of distance but rather an index for special array.
                            let distance = HuffmanTree.Constants.distanceBase[distanceCode] +
                                pointerData.intFromBits(count: extraDistance)

                            // We should repeat last 'distance' amount of data.
                            // The amount of times we do this is round(length / distance).
                            // length actually indicates the amount of data we get from this nextSymbol.
                            let repeatCount: Int = length / distance
                            let arrayToRepeat = Array(repeating: out[out.count - distance..<out.count],
                                                      count: repeatCount).flatMap { $0 }
                            out.append(contentsOf: arrayToRepeat)
                            // Now we deal with the remainings.
                            if length - distance * repeatCount == distance {
                                out.append(contentsOf: out[out.count - distance..<out.count])
                            } else {
                                out.append(contentsOf: out[out.count - distance..<out.count + length - distance * (repeatCount + 1)])
                            }
                        } else {
                            throw DeflateError.HuffmanTableError
                        }
                    } else {
                        throw DeflateError.HuffmanTableError
                    }
                }

            } else {
                throw DeflateError.UnknownBlockType
            }

            // End the cycle if it was the last block.
            if isLastBit == 1 { break }
        }

        return Data(bytes: out)
    }

}
