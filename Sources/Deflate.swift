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
 
 - `WrongUncompressedBlockLengths`: `length` and `nlength` bytes of uncompressed block were not compatible.
 - `WrongBlockType`: unsupported block type (not 0, 1 or 2).
 - `WrongSymbol`: unsupported Huffman tree's symbol.
 - `SymbolNotFound`: symbol from input data was not found in Huffman tree.
 */
public enum DeflateError: Error {
    /// Uncompressed block' `length` and `nlength` bytes were not compatible.
    case WrongUncompressedBlockLengths
    /// Unknown block type (not from 0 to 2).
    case WrongBlockType
    /// Decoded symbol was found in Huffman tree but is unknown.
    case WrongSymbol
    /// Symbol was not found in Huffman tree.
    case SymbolNotFound
}

/// Provides function to decompress data, which were compressed with DEFLATE.
public final class Deflate: DecompressionAlgorithm {

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
                guard length & nlength == 0 else { throw DeflateError.WrongUncompressedBlockLengths }
                // Process uncompressed data into the output
                for _ in 0..<length {
                    out.append(pointerData.alignedByte())
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
                    // Moreover, they are stored in a very specific order (defined by HuffmanTree.Constants.codeLengthOrders).
                    var lengthsForOrder = Array(repeating: 0, count: 19)
                    for i in 0..<codeLengthsLength {
                        lengthsForOrder[HuffmanTree.Constants.codeLengthOrders[i]] = pointerData.intFromBits(count: 3)
                    }
                    /// Huffman table for code lengths. Each code in the main alphabets is coded with this table.
                    let dynamicCodes = HuffmanTree(lengthsToOrder: lengthsForOrder, &pointerData)

                    // Now we need to read codes (code lengths) for two main alphabets (tables).
                    var codeLengths: [Int] = []
                    var n = 0
                    while n < (literals + distances) {
                        // Finding next Huffman table's symbol in data.
                        let symbol = dynamicCodes.findNextSymbol()
                        guard symbol != -1 else { throw DeflateError.SymbolNotFound }

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
                            throw DeflateError.WrongSymbol
                        }
                        for _ in 0..<count {
                            codeLengths.append(what)
                        }
                        n += count
                    }
                    // We have read codeLengths for both tables at once.
                    // Now we need to split them and make corresponding tables.
                    mainLiterals = HuffmanTree(lengthsToOrder: Array(codeLengths[0..<literals]), &pointerData)
                    mainDistances = HuffmanTree(lengthsToOrder: Array(codeLengths[literals..<codeLengths.count]), &pointerData)
                }

                // Main loop of data decompression.
                while true {
                    // Read next symbol from data.
                    // It will be either literal symbol or a length of (previous) data we will need to copy.
                    let nextSymbol = mainLiterals.findNextSymbol()
                    guard nextSymbol != -1 else { throw DeflateError.SymbolNotFound }

                    if nextSymbol >= 0 && nextSymbol <= 255 {
                        // It is a literal symbol so we add it straight to the output data.
                        print("raw symbol: \(nextSymbol)")
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

                        print("length: \(length)")

                        // Then we need to get distance code.
                        let distanceCode = mainDistances.findNextSymbol()
                        guard distanceCode != -1 else { throw DeflateError.SymbolNotFound }
                        guard distanceCode >= 0 && distanceCode <= 29
                            else { throw DeflateError.WrongSymbol }

                        // Again, depending on the distanceCode's value there might be additional bits in data,
                        // which we need to combine with distanceCode to get the actual distance.
                        let extraDistance = distanceCode == 0 || distanceCode == 1 ? 0 : ((distanceCode >> 1) - 1)
                        // And yes, distanceCode is not a first part of distance but rather an index for special array.
                        let distance = HuffmanTree.Constants.distanceBase[distanceCode] +
                            pointerData.intFromBits(count: extraDistance)

                        print("distance: \(distance)")
                        
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
                        throw DeflateError.WrongSymbol
                    }
                }

            } else {
                throw DeflateError.WrongBlockType
            }

            // End the cycle if it was the last block.
            if isLastBit == 1 { break }
        }

        return out
    }

    // TODO: Remove public when release.
    public static func lengthEncode(_ rawBytes: [UInt8], _ dictSize: Int = 1 << 12) -> [UInt8] {
        var dictionary: [UInt8] = Array(repeating: 0, count: dictSize)
        var buffer: [UInt8] = []
        var dictPos = 0
        var inputIndex = 0
        while inputIndex < rawBytes.count {
            let byte = rawBytes[inputIndex]
            inputIndex += 1

            if let matchStartIndex = dictionary.index(of: byte) {
                var matchEndIndex = matchStartIndex + 1
                var matchLength: UInt8 = 1

                while inputIndex < rawBytes.count {
                    if rawBytes[inputIndex] == dictionary[matchStartIndex + matchLength.toInt()] {

                        matchEndIndex += 1
                        if matchEndIndex >= dictSize {
                            matchEndIndex = 0
                        }

                        inputIndex += 1
                        matchLength += 1
                    } else {
                        break
                    }
                }

                if matchLength < 3 {
                    while matchLength > 0 {
                        buffer.append(rawBytes[inputIndex - matchLength.toInt()])
                        matchLength -= 1
                    }
                } else {
                    buffer.append(matchLength)
                    buffer.append(UInt8(matchStartIndex))
                }
            } else {
                buffer.append(byte)

                dictionary[dictPos] = byte
                dictPos += 1
                if dictPos >= dictSize {
                    dictPos = 0
                }
            }

        }
        return buffer
    }


}
