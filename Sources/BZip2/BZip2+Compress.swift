// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension BZip2: CompressionAlgorithm {

    /**
     Compresses `data` with BZip2 algortihm.

     - Parameter data: Data to compress.

     - Note: Input data will be split into blocks of size 100 KB. Use `BZip2.compress(data:blockSize:)` function to
     specify the size of a block.
     */
    public static func compress(data: Data) -> Data {
        return compress(data: data, blockSize: .one)
    }

    private static let blockMarker: [UInt8] = [
        0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,
        0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0,
        0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1
    ]

    private static let eosMarker: [UInt8] = [
        0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0,
        0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0,
        0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0
    ]

    /**
     Compresses `data` with BZip2 algortihm, splitting data into blocks of specified `blockSize`.

     - Parameter data: Data to compress.
     - Parameter blockSize: Size of blocks in which `data` will be split.
     */
    public static func compress(data: Data, blockSize: BlockSize) -> Data {
        let bitWriter = MsbBitWriter()
        // We intentionally use smaller block size for compression to account for potential data size expansion
        // after intial RLE, which seems to be not being expected by original BZip2 implementation.
        // In the worst case initial RLE causes expansion by a factor of 1.25, so 1000 / 1.25 = 800.
        let rawBlockSize = blockSize.sizeInKilobytes * 800
        // BZip2 Header.
        bitWriter.write(unsignedNumber: 0x425a, bitsCount: 16) // Magic number = 'BZ'.
        bitWriter.write(unsignedNumber: 0x68, bitsCount: 8) // Version = 'h'.
        bitWriter.write(number: blockSize.headerByte, bitsCount: 8) // Block size.

        var totalCRC: UInt32 = 0
        for i in stride(from: data.startIndex, to: data.endIndex, by: rawBlockSize) {
            let block = data[i..<min(data.endIndex, i + rawBlockSize)].toByteArray()
            let blockCRC = CheckSums.bzip2crc32(block)

            totalCRC = (totalCRC << 1) | (totalCRC >> 31)
            totalCRC ^= blockCRC

            // Start block header.
            bitWriter.write(bits: blockMarker) // Block magic number.
            bitWriter.write(number: blockCRC.toInt(), bitsCount: 32) // Block crc32.

            process(block, bitWriter)
        }

        // EOS magic number.
        bitWriter.write(bits: eosMarker)
        // Total crc32.
        bitWriter.write(number: totalCRC.toInt(), bitsCount: 32)

        bitWriter.align()
        return bitWriter.data
    }

    private static func process(_ block: [UInt8], _ bitWriter: MsbBitWriter) {
        var out = initialRle(block)

        var pointer = 0
        (out, pointer) = BurrowsWheeler.transform(bytes: out)

        let usedBytes = Set(out).sorted()
        var maxSymbol = 0
        (out, maxSymbol) = mtfRle(out, characters: usedBytes)

        // First, we analyze data and create Huffman trees and selectors.
        // Then we will perform encoding itself.
        // These are separate stages because all information about trees is stored at the beginning of the block,
        //  and it is hard to modify it later.
        var processed = 50
        var tables = [EncodingTree]()
        var tablesLengths = [[Int]]()
        var selectors = [Int]()

        // Algorithm for code lengths calculations skips any symbol with frequency equal to 0.
        // Unfortunately, we need such unused symbols in tree creation, so we cannot skip them.
        // To prevent skipping, we set default value of 1 for every symbol's frequency.
        var stats = Array(repeating: 1, count: maxSymbol + 2)

        for i in 0..<out.count {
            let symbol = out[i]
            stats[symbol] += 1
            processed -= 1
            if processed <= 0 || i == out.count - 1 {
                processed = 50

                // Let's find minimum possible sizes for our stats using existing tables.
                var minimumSize = Int.max
                var minimumSelector = -1
                for tableIndex in 0..<tables.count {
                    let bitSize = tables[tableIndex].bitSize(for: stats)
                    if bitSize < minimumSize {
                        minimumSize = bitSize
                        minimumSelector = tableIndex
                    }
                }

                // If we already have 6 tables, we cannot create more, thus we choose one of the existing tables.
                if tables.count == 6 {
                    selectors.append(minimumSelector)
                } else {
                    // Otherwise, let's create a new table and check if it gives us better results.
                    // First, we calculate code lengths and codes for our current stats.
                    let lengths = BZip2.lengths(from: stats)
                    let codes = Code.huffmanCodes(from: lengths).codes
                    // Then, using these codes, we create a new Huffman tree.
                    let table = EncodingTree(codes, bitWriter)
                    if table.bitSize(for: stats) < minimumSize {
                        tables.append(table)
                        tablesLengths.append(lengths.sorted { $0.symbol < $1.symbol }.map { $0.codeLength })
                        selectors.append(tables.count - 1)
                    } else {
                        selectors.append(minimumSelector)
                    }
                }

                // Clear stats.
                stats = Array(repeating: 1, count: maxSymbol + 2)
            }
        }

        // Format requires at least two tables to be present.
        // If we have only one, we add a duplicate of it.
        if tables.count == 1 {
            tables.append(tables[0])
            tablesLengths.append(tablesLengths[0])
        }

        // Now, we perform encoding itself.
        // But first, we need to finish block header.
        bitWriter.write(bit: 0) // "Randomized".
        bitWriter.write(number: pointer, bitsCount: 24) // Original pointer (from BWT).

        // Encode which symbols (bytes) are used in the data. All possible 256 symbols (0...255) are split into "maps"
        // of 16 consequent symbols. Each map is a sequence of 16 bits where a set bit indicates that a symbol is used.
        // If a map would consist of only zero bits, then it is omitted. This is determined in the construction of `usedMap`.
        var usedMap = Array(repeating: 0 as UInt8, count: 16)
        for usedByte in usedBytes {
            // `usedBytes` is an output of the BW transform which does not change symbols used. The input of the BW
            // transform is an output of initial RLE encoding. Since a run length value is 255 or less and the input
            // data consists of normal bytes which also have values of 255 or less, `usedByte` cannot be larger than 255
            // by construction.
            assert(usedByte <= 255, "Incorrect usedByte.")
            usedMap[usedByte / 16] = 1
        }
        bitWriter.write(bits: usedMap)

        var usedBytesIndex = 0
        for i in 0..<16 {
            guard usedMap[i] == 1 else { continue }
            for j in 0..<16 {
                if usedBytesIndex < usedBytes.endIndex && i * 16 + j == usedBytes[usedBytesIndex] {
                    bitWriter.write(bit: 1)
                    usedBytesIndex += 1
                } else {
                    bitWriter.write(bit: 0)
                }
            }
        }

        bitWriter.write(number: tables.count, bitsCount: 3)
        bitWriter.write(number: selectors.count, bitsCount: 15)

        // Selectors are indices into `tables` list, so by construction they can only take values between 0 and
        // `tables.count - 1`. This correspondingly limits the list of characters for the MTF transform.
        let mtfSelectors = mtf(selectors, maxValue: tables.count - 1)
        for selector in mtfSelectors {
            // The output of MTF transform are the indices into the supplied characters list. Since the length of the
            // characters list is given by `tables.count`, by construction `selector` should be between 0 and
            // `tables.count - 1`.
            assert(selector < tables.count)
            bitWriter.write(bits: Array(repeating: 1, count: selector))
            bitWriter.write(bit: 0)
        }

        // Delta bit lengths.
        for lengths in tablesLengths {
            // Starting length.
            var lastLength = lengths[0]
            bitWriter.write(number: lastLength, bitsCount: 5)
            for length in lengths {
                // In the worst case delta between two lengths is 19. This delta requires 19 * 2 = 38 bits to encode
                // which fits into `UInt` (at least, on modern 64-bit systems), so we can use `write(unsignedNumber:)`.
                if lastLength > length {
                    // Bits: 11 -> 11_11 -> 11_11_11 -> 11_11_11_11 -> ...
                    // Numbers: 3 -> 15 -> 63 -> 255 -> ...
                    // https://oeis.org/A024036
                    let diff = lastLength - length
                    bitWriter.write(unsignedNumber: (1 << (2 * diff)) - 1, bitsCount: 2 * diff)
                } else if lastLength < length {
                    // Bits: 10 -> 10_10 -> 10_10_10 -> 10_10_10_10 -> ...
                    // Numbers: 2 -> 10 -> 42 -> 170 -> ...
                    // https://oeis.org/A020988
                    let diff = length - lastLength
                    bitWriter.write(unsignedNumber: ((1 << (2 * diff)) - 1) * 2 / 3 , bitsCount: 2 * diff)
                }
                lastLength = length
                bitWriter.write(bit: 0)
            }
        }

        // Contents.
        var encoded = 0
        var table = tables[selectors[selectors.startIndex]]
        var selectorIndex = selectors.startIndex &+ 1
        for symbol in out {
            // New table is selected every 50 symbols.
            if encoded >= 50 {
                // Selectors were added every 50 symbols. So by construction `selectorIndex` can never exceed the
                // amount of available selectors.
                assert(selectorIndex < selectors.endIndex, "Incorrect selectorIndex.")
                table = tables[selectors[selectorIndex]]
                selectorIndex &+= 1
                encoded = 0
            }
            table.code(symbol: symbol)
            encoded &+= 1
        }
    }

    /// Initial Run Length Encoding.
    private static func initialRle(_ block: [UInt8]) -> [Int] {
        var out = [Int]()
        var index = block.startIndex
        while index < block.endIndex {
            var runLength = 1
            while index + 1 < block.endIndex && block[index] == block[index + 1] && runLength < 255 {
                runLength += 1
                index += 1
            }
            let byte = block[index].toInt()
            for _ in 0..<min(4, runLength) {
                out.append(byte)
            }
            if runLength >= 4 {
                out.append(runLength - 4)
            }
            index += 1
        }
        return out
    }

    /// Assumes that the characters are given by a list of integers from 0 up to and including `maxValue`.
    private static func mtf(_ array: [Int], maxValue: Int) -> [Int] {
        var out = [Int]()
        var dictionary = Array(0...maxValue)
        for i in 0..<array.count {
            let index = dictionary.firstIndex(of: array[i])!
            out.append(index)
            let old = dictionary.remove(at: index)
            dictionary.insert(old, at: 0)
        }
        return out
    }

    private static func mtfRle(_ array: [Int], characters: [Int]) -> ([Int], Int) {
        var out = [Int]()
        /// Mutable copy of `characters`.
        var dictionary = characters
        var lengthOfZerosRun = 0
        var maxSymbol = 1
        for i in 0..<array.count {
            let byte = dictionary.firstIndex(of: array[i])!

            // Run length encoding of zeros.
            if byte == 0 {
                lengthOfZerosRun += 1
            }
            if (byte == 0 && i == array.count - 1) || byte != 0 {
                // Runs of zeros are represented using a modified binary system with two "digits", RUNA and RUNB, where
                //  RUNA represents 1 and RUNB represents 2 (whereas in the usual base-2 system the digits are 0 and 1).
                // (We don't need a digit for zero since we can't get a run of length 0 by definition.)
                if lengthOfZerosRun > 0 {
                    let digitsNumber = Int(floor(log2(Double(lengthOfZerosRun) + 1)))
                    var remainder = lengthOfZerosRun
                    for _ in 0..<digitsNumber {
                        let quotient = Int(ceil(Double(remainder) / 2) - 1)
                        let digit = remainder - quotient * 2
                        if digit == 1 {
                            out.append(0)
                        } else {
                            out.append(1)
                        }
                        remainder = quotient
                    }
                    lengthOfZerosRun = 0
                }
            }
            if byte != 0 {
                // We add one, because 1 is used as RUNB.
                let newSymbol = byte + 1
                out.append(newSymbol)
                if newSymbol > maxSymbol {
                    maxSymbol = newSymbol
                }
            }

            // Move to the front.
            let old = dictionary.remove(at: byte)
            dictionary.insert(old, at: 0)
        }
        // Add the 'end of stream' symbol.
        out.append(maxSymbol + 1)
        return (out, maxSymbol)
    }

}
