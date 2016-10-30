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
        var out: [String] = []

        // Current point of processing in data
        var index = 0
        while true {
            // Is this a last block?
            let isLastBit = data[index][0]
            // Type of the current block
            let blockType = [UInt8](data[index][1..<3].reversed())
            var shift = 3

            if blockType == [0, 0] { // Uncompressed block
                // Get length of the uncompressed data
                index += 1

                // TODO: Check if straight to `int` conversion works
                let length = Data(data[index...index + 1]).to(type: UInt16.self).toInt()
                index += 2
                // Get 1-complement of the length
                let nlength = Data(data[index...index + 1]).to(type: UInt16.self).toInt()
                index += 2
                // Check if lengths are OK
                guard length & nlength == 0 else { throw DeflateError.WrongBlockLengths }
                // Process uncompressed data into the output
                for _ in 0..<length {
                    out.append("".appending(String(UnicodeScalar(data[index]))))
                    index += 1
                }
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
                    let literals = convertToInt(reversedUint8Array:
                        data.bits(from: (index, shift), to: (index, shift + 5))) + 257
                    index += 1
                    shift = 0
                    let distances = convertToInt(reversedUint8Array:
                        data.bits(from: (index, shift), to: (index, shift + 5))) + 1
                    shift = 5
                    let codeLengthsLength = convertToInt(reversedUint8Array:
                        data.bits(from: (index, shift), to: (index + 1, 1))) + 4
                    index += 1
                    shift = 1

                    var lengthsForOrder = Array(repeating: 0, count: 19)
                    for i in 0..<codeLengthsLength {
                        let start = (index, shift)
                        index += shift + 3 >= 8 ? 1 : 0
                        shift = shift + 3 >= 8 ? shift - 5 : shift + 3
                        let end = (index, shift)
                        lengthsForOrder[HuffmanTable.Constants.codeLengthOrders[i]] =
                            convertToInt(reversedUint8Array: data.bits(from: start, to: end))
                    }
                    let dynamicCodes = HuffmanTable(lengthsToOrder: lengthsForOrder)

                    var codeLengths: [Int] = []
                    var n = 0
                    while n < (literals + distances) {
                        let tuple = dynamicCodes.findNextSymbol(in: Data(data[index...index + 2]),
                                                                withShift: shift)
                        let symbol = tuple.symbol
                        guard symbol != -1 else { throw DeflateError.HuffmanTableError }
                        index += tuple.addToIndex
                        shift = tuple.newShift
                        let count: Int
                        let what: Int
                        if symbol >= 0 && symbol <= 15 {
                            count = 1
                            what = symbol
                        } else if symbol == 16 {
                            let start = (index, shift)
                            index += shift + 2 >= 8 ? 1 : 0
                            shift = shift + 2 >= 8 ? shift - 6 : shift + 2
                            let end = (index, shift)
                            count = 3 + convertToInt(reversedUint8Array:
                                data.bits(from: start, to: end))
                            what = codeLengths.last!
                        } else if symbol == 17 {
                            let start = (index, shift)
                            index += shift + 3 >= 8 ? 1 : 0
                            shift = shift + 3 >= 8 ? shift - 5 : shift + 3
                            let end = (index, shift)
                            count = 3 + convertToInt(reversedUint8Array:
                                data.bits(from: start, to: end))
                            what = 0
                        } else if symbol == 18 {
                            let start = (index, shift)
                            index += shift + 7 >= 8 ? 1 : 0
                            shift = shift + 7 >= 8 ? shift - 1 : shift + 7
                            let end = (index, shift)
                            count = 11 + convertToInt(reversedUint8Array:
                                data.bits(from: start, to: end))
                            what = 0
                        } else {
                            throw DeflateError.HuffmanTableError
                        }
                        codeLengths.append(contentsOf: Array(repeating: what, count: count))
                        n += count
                    }
                    mainLiterals = HuffmanTable(lengthsToOrder:
                        Array(codeLengths[0..<literals]))
                    mainDistances = HuffmanTable(lengthsToOrder:
                        Array(codeLengths[literals..<codeLengths.count]))
                }

                while true {
                    let nextSymbol = mainLiterals.findNextSymbol(in: Data(data[index...index + 2]),
                                                                  withShift: shift)
                    let symbol = nextSymbol.symbol
                    guard symbol != -1 else { throw DeflateError.HuffmanTableError }
                    index += nextSymbol.addToIndex
                    shift = nextSymbol.newShift

                    if symbol >= 0 && symbol <= 255 {
                        out.append("".appending(String(UnicodeScalar(UInt8(truncatingBitPattern:
                            UInt(symbol))))))
                    } else if symbol == 256 {
                        break
                    } else if symbol >= 257 && symbol <= 285 {
                        let start = (index, shift)
                        let addBits = HuffmanTable.Constants.extraLengthBits(n: symbol)
                        guard addBits != -1 else { throw DeflateError.HuffmanTableError }
                        index += shift + addBits >= 8 ? 1 : 0
                        shift = shift + addBits >= 8 ? shift - (8 - addBits) : shift + addBits
                        let end = (index, shift)
                        var length = HuffmanTable.Constants.lengthBase[symbol - 257] +
                            convertToInt(reversedUint8Array: data.bits(from: start, to: end))

                        let newSymbolTuple = mainDistances.findNextSymbol(in:
                            Data(data[index...index + 2]), withShift: shift)
                        let newSymbol = newSymbolTuple.symbol
                        guard newSymbol != -1 else { throw DeflateError.HuffmanTableError }
                        index += newSymbolTuple.addToIndex
                        shift = newSymbolTuple.newShift

                        if newSymbol >= 0 && newSymbol <= 29 {
                            let start = (index, shift)
                            let extraDistance = HuffmanTable.Constants.extraDistanceBits(n: newSymbol)
                            guard extraDistance != -1 else { throw DeflateError.HuffmanTableError }
                            if shift + extraDistance >= 16 {
                                index += 2
                                shift = shift - (16 - extraDistance)
                            } else if shift + extraDistance >= 8 {
                                index += 1
                                shift = shift - (8 - extraDistance)
                            } else {
                                shift += extraDistance
                            }
                            let end = (index, shift)
                            let distance = HuffmanTable.Constants.distanceBase[newSymbol] +
                                convertToInt(reversedUint8Array: data.bits(from: start, to: end))

                            while length > distance {
                                out.append(contentsOf: Array(out[out.count - distance..<out.count]))
                                length -= distance
                            }
                            if length == distance {
                                out.append(contentsOf: Array(out[out.count - distance..<out.count]))
                            } else {
                                out.append(contentsOf: Array(out[out.count - distance..<out.count + length - distance]))
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

        return (String(out.reduce("") { $0 + $1 })?.data(using: .utf8))!
    }

}
