//
//  Deflate.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

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

/// A class with decompression function of DEFLATE algorithm.
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
        /// Object for storing output data
        var out = Data()

        /// Object with input data which supports convenient work with bit shifts
        let pointerData = DataWithPointer(data: data)

        while true {
            /// Is this a last block?
            let isLastBit = pointerData.bit()
            /// Type of the current block
            let blockType = [UInt8](pointerData.bits(count: 2).reversed())

            if blockType == [0, 0] { // Uncompressed block
                pointerData.skipUntilNextByte()

                /// Length of the uncompressed data
                let length = convertToInt(uint8Array: pointerData.bits(count: 16))
                /// 1-complement of the length
                let nlength = convertToInt(uint8Array: pointerData.bits(count: 16))
                // Check if lengths are OK
                // TODO: Rename WrongBlockLengths to WrongUncompressedBlockLengths (or something else)
                guard length & nlength == 0 else { throw DeflateError.WrongBlockLengths }
                // Process uncompressed data into the output
                out.append(pointerData.data(ofBytes: length))
            } else if blockType == [1, 0] || blockType == [0, 1] {
                // Block with Huffman coding (either static or dynamic)

                // Declaration of Huffman tables which will be populated and used later
                var mainLiterals: HuffmanTable
                var mainDistances: HuffmanTable

                if blockType == [0, 1] { // Static Huffman
                    // Bootstraps for tables
                    let staticHuffmanBootstrap = [[0, 8], [144, 9], [256, 7], [280, 8], [288, -1]]
                    let staticHuffmanLengthsBootstrap = [[0, 5], [32, -1]]
                    // Initialize tables from these bootstraps
                    mainLiterals = HuffmanTable(bootstrap: staticHuffmanBootstrap)
                    mainDistances = HuffmanTable(bootstrap: staticHuffmanLengthsBootstrap)
                } else { // Dynamic Huffman
                    let literals = convertToInt(uint8Array: pointerData.bits(count: 5)) + 257
                    let distances = convertToInt(uint8Array: pointerData.bits(count: 5)) + 1
                    let codeLengthsLength = convertToInt(uint8Array: pointerData.bits(count: 4)) + 4

                    var lengthsForOrder = Array(repeating: 0, count: 19)
                    for i in 0..<codeLengthsLength {
                        lengthsForOrder[HuffmanTable.Constants.codeLengthOrders[i]] =
                            convertToInt(uint8Array: pointerData.bits(count: 3))
                    }
                    let dynamicCodes = HuffmanTable(lengthsToOrder: lengthsForOrder)

                    var codeLengths: [Int] = []
                    var n = 0
                    while n < (literals + distances) {
                        guard let dynamicCodeHuffmanLength = dynamicCodes.findNextSymbol(in: pointerData.bits(count: 24)) else {
                            throw DeflateError.HuffmanTableError
                        }
                        pointerData.rewind(bitsCount: 24 - dynamicCodeHuffmanLength.bits)
                        let symbol = dynamicCodeHuffmanLength.code
                        let count: Int
                        let what: Int
                        if symbol >= 0 && symbol <= 15 {
                            count = 1
                            what = symbol
                        } else if symbol == 16 {
                            count = convertToInt(uint8Array: pointerData.bits(count: 2)) + 3
                            what = codeLengths.last!
                        } else if symbol == 17 {
                            count = convertToInt(uint8Array: pointerData.bits(count: 3)) + 3
                            what = 0
                        } else if symbol == 18 {
                            count = convertToInt(uint8Array: pointerData.bits(count: 7)) + 11
                            what = 0
                        } else {
                            throw DeflateError.HuffmanTableError
                        }
                        codeLengths.append(contentsOf: Array(repeating: what, count: count))
                        n += count
                    }
                    mainLiterals = HuffmanTable(lengthsToOrder: Array(codeLengths[0..<literals]))
                    mainDistances = HuffmanTable(lengthsToOrder: Array(codeLengths[literals..<codeLengths.count]))
                }

                while true {
                    guard let nextSymbolLength = mainLiterals.findNextSymbol(in: pointerData.bits(count: 24)) else {
                        throw DeflateError.HuffmanTableError
                    }
                    pointerData.rewind(bitsCount: 24 - nextSymbolLength.bits)
                    let nextSymbol = nextSymbolLength.code

                    if nextSymbol >= 0 && nextSymbol <= 255 {
                        out.append(Data(bytes: [UInt8(truncatingBitPattern: UInt(nextSymbol))]))
                    } else if nextSymbol == 256 {
                        break
                    } else if nextSymbol >= 257 && nextSymbol <= 285 {
                        let extraLength = (257 <= nextSymbol && nextSymbol <= 260) || nextSymbol == 285 ?
                            0 : (((nextSymbol - 257) >> 2) - 1)
                        var length = HuffmanTable.Constants.lengthBase[nextSymbol - 257] +
                            convertToInt(uint8Array: pointerData.bits(count: extraLength))

                        guard let distanceLength = mainDistances.findNextSymbol(in: pointerData.bits(count: 24)) else {
                            throw DeflateError.HuffmanTableError
                        }
                        pointerData.rewind(bitsCount: 24 - distanceLength.bits)
                        let distanceCode = distanceLength.code

                        if distanceCode >= 0 && distanceCode <= 29 {
                            let extraDistance = distanceCode == 0 || distanceCode == 1 ? 0 : ((distanceCode >> 1) - 1)
                            let distance = HuffmanTable.Constants.distanceBase[distanceCode] +
                                convertToInt(uint8Array: pointerData.bits(count: extraDistance))

                            while length > distance {
                                out.append(Data(out[out.count - distance..<out.count]))
                                length -= distance
                            }
                            if length == distance {
                                out.append(Data(out[out.count - distance..<out.count]))
                            } else {
                                out.append(Data(out[out.count - distance..<out.count + length - distance]))
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

            // End the cycle if it was the last block
            if isLastBit == 1 { break }
        }

        return out
    }

}
