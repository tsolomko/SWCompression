//
//  BZip2.swift
//  SWCompression
//
//  Created by Timofey Solomko on 12.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Represents an error, which happened during BZip2 decompression.
 It may indicate that either data is damaged or it might not be compressed with BZip2 at all.
 */
public enum BZip2Error: Error {
    /// 'Magic' number is not 0x425a.
    case wrongMagic
    /// Compression method is not type 'h' (not Huffman).
    case wrongCompressionMethod
    /// Unsupported block size (not from '0' to '9').
    case wrongBlockSize
    /// Unsupported block type (is neither 'pi' nor 'sqrt(pi)').
    case wrongBlockType
    /// Block is randomized.
    case randomizedBlock
    /// Wrong number of Huffman tables/groups (should be between 2 and 6).
    case wrongHuffmanGroups
    /// Selector is greater than the total number of Huffman tables/groups.
    case wrongSelector
    /// Wrong code of Huffman length (should be between 0 and 20).
    case wrongHuffmanLengthCode
    /// Symbol wasn't found in Huffman tree.
    case symbolNotFound
    /**
     Computed checksum of uncompressed data doesn't match the value stored in archive.
     Associated value of the error contains already decompressed data.
     */
    case wrongCRC(Data)
}

/// Provides decompression function for BZip2 algorithm.
public class BZip2: DecompressionAlgorithm {

    /**
     Decompresses `data` using BZip2 algortihm.

     If `data` is not actually compressed with BZip2, `BZip2Error` will be thrown.

     - Parameter data: Data compressed with BZip2.

     - Throws: `BZip2Error` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with BZip2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .straight)
        return Data(bytes: try decompress(&pointerData))
    }

    static func decompress(_ pointerData: inout DataWithPointer) throws -> [UInt8] {
        /// An array for storing output data
        var out = [UInt8]()

        let magic = pointerData.intFromBits(count: 16)
        guard magic == 0x425a else { throw BZip2Error.wrongMagic }

        let method = pointerData.intFromBits(count: 8)
        guard method == 104 else { throw BZip2Error.wrongCompressionMethod }

        var blockSize = pointerData.intFromBits(count: 8)
        if blockSize >= 49 && blockSize <= 57 {
            blockSize -= 48
        } else {
            throw BZip2Error.wrongBlockSize
        }

        while true {
            let blockType: Int64 = Int64(pointerData.intFromBits(count: 48))
            // Next 32 bits are crc (which currently is not checked).
            let blockCRC32 = UInt32(truncatingBitPattern: pointerData.intFromBits(count: 32))

            if blockType == 0x314159265359 {
                let blockBytes = try decode(data: &pointerData)
                guard CheckSums.bzip2CRC32(blockBytes) == blockCRC32
                    else { throw BZip2Error.wrongCRC(Data(bytes: out)) }
                for byte in blockBytes {
                    out.append(byte)
                }
            } else if blockType == 0x177245385090 {
                guard CheckSums.bzip2CRC32(out) == blockCRC32
                    else { throw BZip2Error.wrongCRC(Data(bytes: out)) }
                break
            } else {
                throw BZip2Error.wrongBlockType
            }
        }

        return out
    }

    private static func decode(data: inout DataWithPointer) throws -> [UInt8] {
        let isRandomized = data.bit()
        guard isRandomized != 1 else { throw BZip2Error.randomizedBlock }

        var pointer = data.intFromBits(count: 24)

        func computeUsed() -> [Bool] {
            let huffmanUsedMap = data.intFromBits(count: 16)
            var mapMask = 1 << 15
            var used: [Bool] = []
            while mapMask > 0 {
                if huffmanUsedMap & mapMask > 0 {
                    let huffmanUsedBitmap = data.intFromBits(count: 16)
                    var bitMask = 1 << 15
                    while bitMask > 0 {
                        used.append(huffmanUsedBitmap & bitMask > 0)
                        bitMask >>= 1
                    }
                } else {
                    for _ in 0..<16 {
                        used.append(false)
                    }
                }
                mapMask >>= 1
            }
            return used
        }

        let used = computeUsed()

        let huffmanGroups = data.intFromBits(count: 3)
        guard huffmanGroups >= 2 && huffmanGroups <= 6 else { throw BZip2Error.wrongHuffmanGroups }

        func computeSelectorsList() throws -> [Int] {
            let selectorsUsed = data.intFromBits(count: 15)

            var mtf: [Int] = Array(0..<huffmanGroups)
            var selectorsList: [Int] = []

            for _ in 0..<selectorsUsed {
                var c = 0
                while data.bit() > 0 {
                    c += 1
                    guard c < huffmanGroups else { throw BZip2Error.wrongSelector }
                }
                if c >= 0 {
                    let el = mtf.remove(at: c)
                    mtf.insert(el, at: 0)
                }
                selectorsList.append(mtf[0])
            }

            return selectorsList
        }

        let selectorsList = try computeSelectorsList()
        let symbolsInUse = used.filter { $0 }.count + 2

        func computeTables() throws -> [HuffmanTree] {
            var tables: [HuffmanTree] = []
            for _ in 0..<huffmanGroups {
                var length = data.intFromBits(count: 5)
                var lengths: [Int] = []
                for _ in 0..<symbolsInUse {
                    guard length >= 0 && length <= 20 else { throw BZip2Error.wrongHuffmanLengthCode }
                    while data.bit() > 0 {
                        length -= (Int(data.bit() * 2) - 1)
                    }
                    lengths.append(length)
                }
                let codes = HuffmanTree(lengthsToOrder: lengths, &data)
                tables.append(codes)
            }

            return tables
        }

        let tables = try computeTables()
        var favourites = try used.enumerated().reduce([]) {
            (partialResult: [UInt8], next: (offset: Int, element: Bool)) throws -> [UInt8] in
            if next.element {
                var newResult = partialResult
                newResult.append(next.offset.toUInt8())
                return newResult
            } else {
                return partialResult
            }
        }

        var selectorPointer = 0
        var decoded = 0
        var repeat_ = 0
        var repeatPower = 0
        var buffer: [UInt8] = []
        var t: HuffmanTree?

        while true {
            decoded -= 1
            if decoded <= 0 {
                decoded = 50
                if selectorPointer <= selectorsList.count {
                    t = tables[selectorsList[selectorPointer]]
                    selectorPointer += 1
                }
            }

            guard let symbol = t?.findNextSymbol() else { throw BZip2Error.symbolNotFound }
            guard symbol != -1 else { throw BZip2Error.symbolNotFound }

            if symbol == 1 || symbol == 0 {
                if repeat_ == 0 {
                    repeatPower = 1
                }
                repeat_ += repeatPower << symbol
                repeatPower <<= 1
                continue
            } else if repeat_ > 0 {
                for _ in 0..<repeat_ {
                    buffer.append(favourites[0])
                }
                repeat_ = 0
            }
            if symbol == symbolsInUse - 1 {
                break
            } else {
                let o = favourites[symbol - 1]
                let el = favourites.remove(at: symbol - 1)
                favourites.insert(el, at: 0)
                buffer.append(o)
            }
        }

        func bwt(transform bytes: [UInt8]) -> [Int] {
            let sortedBytes = bytes.sorted()
            var base: [Int] = Array(repeating: -1, count: 256)
            for i in 0..<256 {
                base[i] = sortedBytes.index(of: i.toUInt8()) ?? -1
            }

            var pointers: [Int] = Array(repeating: -1, count: bytes.count)
            for (i, char) in bytes.enumerated() {
                pointers[base[char.toInt()]] = i
                base[char.toInt()] += 1
            }

            return pointers
        }

        func bwt(reverse bytes: [UInt8], end: inout Int) -> [UInt8] {
            var resultBytes: [UInt8] = []
            if bytes.count > 0 {
                let T = bwt(transform: bytes)
                for _ in 0..<bytes.count {
                    end = T[end]
                    resultBytes.append(bytes[end])
                }
            }
            return resultBytes
        }

        let nt = bwt(reverse: buffer, end: &pointer)
        var i = 0
        var out: [UInt8] = []
        while i < nt.count {
            if (i < nt.count - 4) && (nt[i] == nt[i + 1]) && (nt[i] == nt[i + 2]) && (nt[i] == nt[i + 3]) {
                let sCount = nt[i + 4].toInt() + 4
                for _ in 0..<sCount {
                    out.append(nt[i])
                }
                i += 5
            } else {
                out.append(nt[i])
                i += 1
            }
        }

        return out
    }

}
