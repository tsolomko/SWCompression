//
//  Deflate.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

public enum DeflateError: Error {
    case WrongMagic
    case UnknownCompressionMethod
    case WrongBlockLengths
    case HuffmanTableError
    case UnknownBlockType
}

public class Deflate {

    struct Flags {
        static let ftext: UInt8 = 0x01
        static let fhcrc: UInt8 = 0x02
        static let fextra: UInt8 = 0x04
        static let fname: UInt8 = 0x08
        static let fcomment: UInt8 = 0x10
    }

    struct ServiceInfo {
        let magic: [UInt8]
        let method: UInt8
        let flags: UInt8
        let mtime: UInt64
        let extraFlags: UInt8
        let osType: UInt8
    }

    public static func decompress(data: Data) throws -> Data {
        // First two bytes should be correct 'magic' bytes
        let magic = data.bytes(from: 0..<2)
        guard magic == [31, 139] else { throw DeflateError.WrongMagic }

        // Third byte is a method of compression. Only type 8 (DEFLATE) compression is supported
        let method = data[2]
        guard method == 8 else { throw DeflateError.UnknownCompressionMethod }

        // Next bytes present some service information
        let serviceInfo = ServiceInfo(magic: magic,
                                      method: method,
                                      flags: data[3],
                                      mtime: Data(data[4...7]).to(type: UInt64.self),
                                      extraFlags: data[8],
                                      osType: data[9])
        print("\(serviceInfo)")

        var startPoint = 10 // Index in data of 'actual data'

        // Some archives may contain extra fields
        if serviceInfo.flags & Flags.fextra != 0 {
            let xlen = Data(data[startPoint...startPoint + 1]).to(type: UInt16.self).toInt()
            startPoint += 2 + xlen
        }

        // Some archives may contain source file name (this part ends with zero byte)
        if serviceInfo.flags & Flags.fname != 0 {
            let fnameStart = startPoint
            while true {
                let byte = data[startPoint]
                startPoint += 1
                guard byte != 0 else { break }
            }
            print(String(data: Data(data[fnameStart..<startPoint - 1]), encoding: .utf8))
        }

        // Some archives may contain comment (this part also ends with zero)
        if serviceInfo.flags & Flags.fcomment != 0 {
            let fcommentStart = startPoint
            while true {
                let byte = data[startPoint]
                startPoint += 1
                guard byte != 0 else { break }
            }
            print(String(data: Data(data[fcommentStart..<startPoint - 1]), encoding: .utf8))
        }

        // Some archives may contain 2-bytes checksum
        if serviceInfo.flags & Flags.fhcrc != 0 {
            let crc = Data(data[startPoint...startPoint + 1]).to(type: UInt16.self)
            startPoint += 2
            print("\(crc)")
        }

        var out: [String] = []

        // Current point of processing in data
        var index = startPoint
        while true {
            // Is this a last block?
            let isLastBit = data[index][0]
            // Type of the current block
            let blockType = [UInt8](data[index][1..<3].reversed())
            var shift = 3
            print("blockType: \(convertToInt(uint8Array: blockType))")

            if blockType == [0, 0] { // Uncompressed block
                // Get length of the uncompressed data
                index += 1

                // CHECK IF STRAIGHT CONVERSION TO INT WITH 'TO' METHOD WORKS
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
                    let literals = convertToInt(uint8Array:
                        data.bits(from: (index, shift), to: (index, shift + 5))) + 257
                    index += 1
                    shift = 0
                    let distances = convertToInt(uint8Array:
                        data.bits(from: (index, shift), to: (index, shift + 5))) + 1
                    shift = 5
                    let codeLengthsLength = convertToInt(uint8Array: data.bits(from: (index, shift), to: (index + 1, 1))) + 4
                    index += 1
                    shift = 1

                    var lengthsForOrder = Array(repeating: 0, count: 19)
                    for i in 0..<codeLengthsLength {
                        let start = (index, shift)
                        index += shift + 3 >= 8 ? 1 : 0
                        shift = shift + 3 >= 8 ? shift - 5 : shift + 3
                        let end = (index, shift)
                        lengthsForOrder[HuffmanTable.Constants.codeLengthOrders[i]] =
                            convertToInt(uint8Array: data.bits(from: start, to: end))
                    }
                    let dynamicCodes = HuffmanTable(lengthsToOrder: lengthsForOrder)

                    var codeLengths: [Int] = []
                    var n = 0
                    while n < (literals + distances) {
                        let tuple = dynamicCodes.findNextSymbol(in: Data(data[index...index + 1]),
                                                                withShift: shift)
                        let symbol = tuple.symbol
                        guard symbol != -1 else { throw DeflateError.HuffmanTableError }
                        index += tuple.addToIndex
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
                            count = 3 + convertToInt(uint8Array:
                                data.bits(from: start, to: end))
                            what = codeLengths.last!
                        } else if symbol == 17 {
                            let start = (index, shift)
                            index += shift + 3 >= 8 ? 1 : 0
                            shift = shift + 3 >= 8 ? shift - 5 : shift + 3
                            let end = (index, shift)
                            count = 3 + convertToInt(uint8Array:
                                data.bits(from: start, to: end))
                            what = 0
                        } else if symbol == 18 {
                            let start = (index, shift)
                            index += shift + 7 >= 8 ? 1 : 0
                            shift = shift + 7 >= 8 ? shift - 1 : shift + 7
                            let end = (index, shift)
                            count = 11 + convertToInt(uint8Array:
                                data.bits(from: start, to: end))
                            what = codeLengths.last!
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
                    let nextSymbol = mainLiterals.findNextSymbol(in: Data(data[index...index + 1]),
                                                                  withShift: shift)
                    let symbol = nextSymbol.symbol
                    guard symbol != -1 else { throw DeflateError.HuffmanTableError }
                    index += nextSymbol.addToIndex
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
                        let extraLength = convertToInt(uint8Array: data.bits(from: start, to: end))
                        var length = HuffmanTable.Constants.lengthBase[symbol - 257] + extraLength

                        let newSymbolTuple = mainDistances.findNextSymbol(in: Data(data[index...index + 1]),
                                                                     withShift: shift)
                        let newSymbol = newSymbolTuple.symbol
                        index += newSymbolTuple.addToIndex

                        if newSymbol >= 0 && newSymbol <= 29 {
                            let start = (index, shift)
                            index += shift + newSymbol >= 8 ? 1 : 0
                            shift = shift + newSymbol >= 8 ? shift - (8 - newSymbol) : shift + newSymbol
                            let end = (index, shift)
                            let dstBase = HuffmanTable.Constants.distanceBase[newSymbol]
                            let distance = dstBase +
                                convertToInt(uint8Array: data.bits(from: start, to: end))
                            print("distance: \(distance), dstBase: \(dstBase), newSymbol: \(newSymbol)")
                            while length > distance {
                                out.append(contentsOf: Array(out[out.count - distance..<out.count]))
                                length -= distance
                            }
                            if length == distance {
                                out.append(contentsOf: Array(out[out.count - distance..<out.count]))
                            } else {
                                out.append(contentsOf: Array(out[out.count - distance..<length - distance]))
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
