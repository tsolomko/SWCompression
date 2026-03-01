// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for compression and decompression for BZip2 algorithm.
public class BZip2: DecompressionAlgorithm {

    /**
     Decompresses `data` using BZip2 algortihm.

     - Parameter data: Data compressed with BZip2.

     - Throws: `BZip2Error` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with BZip2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let bitReader = MsbBitReader(data: data)
        return try decompress(bitReader)
    }

    static func decompress(_ bitReader: MsbBitReader) throws -> Data {
        // Valid BZip2 "archive" must contain at least 14 bytes of data: magic number (2 bytes), method (1 byte), and
        // block size (1 byte).
        guard bitReader.bitsLeft >= 32
            else { throw BZip2Error.wrongMagic }

        /// An array for storing output data
        var out = Data()

        let magic = bitReader.uint16()
        guard magic == 0x5a42 else { throw BZip2Error.wrongMagic }

        let method = bitReader.byte()
        guard method == 104 else { throw BZip2Error.wrongVersion }

        guard let blockSize = BlockSize(bitReader.byte())
            else { throw BZip2Error.wrongBlockSize }

        var totalCRC: UInt32 = 0
        while true {
            // Each BZip2 block must contain block type (6 bytes) and block CRC32 (4 bytes).
            guard bitReader.bitsLeft >= 80
                else { throw BZip2Error.wrongMagic }
            // Using `UInt64` because 48 bits may not fit into `Int` on some platforms.
            let blockType = bitReader.uint64(fromBits: 48)

            let blockCRC32 = bitReader.uint32(fromBits: 32)

            if blockType == 0x314159265359 {
                let block = try decode(bitReader, blockSize)
                out.append(Data(block))
                guard CheckSums.bzip2crc32(block) == blockCRC32
                    else { throw BZip2Error.wrongCRC(out) }
                totalCRC = (totalCRC << 1) | (totalCRC >> 31)
                totalCRC ^= blockCRC32
            } else if blockType == 0x177245385090 {
                guard totalCRC == blockCRC32
                    else { throw BZip2Error.wrongCRC(out) }
                break
            } else {
                throw BZip2Error.wrongBlockType
            }
        }

        return out
    }

    private static func decode(_ bitReader: MsbBitReader, _ blockSize: BlockSize) throws -> [UInt8] {
        // Truncation checks: there is no such thing as "empty BZip2 blocks". Empty data after compression produces
        // only a "CRC32 block". As such when processing a normal BZip2 block we can assume that various BZip2
        // structures (such as table selectors or code lengths) are present, and there are at least some symbols encoded.

        // Randomized bit, pointer (24 bits), and bitmap of used symbol blocks (16 bits) require 41 bits.
        guard bitReader.bitsLeft >= 41
            else { throw BZip2Error.wrongMagic }

        let isRandomized = bitReader.bit()
        guard isRandomized == 0
            else { throw BZip2Error.randomizedBlock }

        let pointer = bitReader.int(fromBits: 24)

        // Decoding which symbols are used in Huffman tables. All possible 256 symbols (0...255) are split into 16 "maps"
        // of 16 sequential symbols. Each map is a sequence of 16 bits where a non-zero bits indicate that used symbols.
        // A map is omitteed if none of its symbols are in use. First, we decode which maps are present.
        let usedBlocksBitMap = bitReader.uint16(fromBits: 16)
        // For each non-zero bit in the bitmap there should be 16 bits of the block. After that there should be 3 bits
        // for the number of Huffman tables and 15 bits for the selectors count.
        guard bitReader.bitsLeft >= 16 * usedBlocksBitMap.nonzeroBitCount + 3 + 15
            else { throw BZip2Error.wrongMagic }

        var blockMask = 1 << 15 as UInt16
        var usedSymbols = [UInt8]()
        while blockMask > 0 {
            if usedBlocksBitMap & blockMask > 0 {
                // Each block, if present, is a set of 16 bits which, if set, represent that the corresponding symbols
                // are in use by Huffman tables.
                let usedSymbolsBitMask = UInt16(bitReader.int(fromBits: 16))
                var symbolMask = 1 << 15 as UInt16
                while symbolMask > 0 {
                    if usedSymbolsBitMask & symbolMask > 0 {
                        usedSymbols.append(UInt8(blockMask.leadingZeroBitCount * 16 + symbolMask.leadingZeroBitCount))
                    }
                    symbolMask >>= 1
                }
            }
            blockMask >>= 1
        }
        // Two additional symbols are RUNA and RUNB.
        let usedSymbolsCount = 2 + usedSymbols.count

        let huffmanTablesCount = bitReader.int(fromBits: 3)
        guard huffmanTablesCount >= 2 && huffmanTablesCount <= 6
            else { throw BZip2Error.wrongHuffmanGroups }

        let selectorsCount = bitReader.int(fromBits: 15)
        var mtf = Array(0..<huffmanTablesCount)

        // It is impossible to calculate in advance how many bits encode table selectors. At minimum, if each selector
        // is encoded by a single zero bit (which means only the zeroth Huffman table is utilized), `selectorsCount`
        // bits are used. At maximum, when all symbols are encoded with the last Huffman table, each selector is given
        // by `huffmanTablesCount - 1` non-zero bits and one zero bit. This gives `huffmanTablesCount * selectorsCount`
        // bits in total.
        // Due to this unpredictability we are forced to check if there are still bits left before every read operation,
        // similarly to how bit reading is done in `DecodingTree.findNextSymbol()`.
        var selectors = [Int]()
        // Accessing `bitsLeft` property of `bitReader` incurs a lot of overhead, so we create a local copy.
        var bitsLeft = bitReader.bitsLeft
        for _ in 0..<selectorsCount {
            var c = 0
            while bitsLeft > 0 {
                let bit = bitReader.bit()
                bitsLeft -= 1
                if bit == 0 {
                    break
                }
                c += 1
            }
            guard c < huffmanTablesCount
                else { throw BZip2Error.wrongSelector }
            let el = mtf.remove(at: c)
            mtf.insert(el, at: 0)
            selectors.append(el)
        }

        // Similar to decoding selectors, code lengths are also encoded in unpredictable manner. As such, we check for
        // input truncation before reading every bit.
        var tables = [DecodingTree]()
        for _ in 0..<huffmanTablesCount {
            guard bitsLeft >= 5
                else { throw BZip2Error.wrongHuffmanCodeLength }
            var length = bitReader.int(fromBits: 5)
            bitsLeft -= 5
            var codeLengths = [CodeLength]()
            for i in 0..<usedSymbolsCount {
                guard length >= 0 && length <= 20
                    else { throw BZip2Error.wrongHuffmanCodeLength }
                while bitsLeft > 0 {
                    let bit = bitReader.bit()
                    bitsLeft -= 1
                    if bit == 0 {
                        break
                    }
                    guard bitsLeft > 0
                        else { throw BZip2Error.wrongHuffmanCodeLength }
                    length -= (bitReader.bit().toInt() * 2 - 1)
                    bitsLeft -= 1
                }
                codeLengths.append(CodeLength(symbol: i, codeLength: length))
            }
            let codes = Code.huffmanCodes(from: codeLengths)
            let table = DecodingTree(codes, bitReader)
            tables.append(table)
        }

        var decoded = 0
        var table = tables[selectors[selectors.startIndex]]
        var selectorIndex = selectors.startIndex &+ 1
        var runLength = 0
        var repeatPower = 1
        var buffer = [UInt8]()

        while true {
            if decoded >= 50 {
                guard selectorIndex < selectorsCount
                    else { throw BZip2Error.wrongSelector }
                table = tables[selectors[selectorIndex]]
                selectorIndex &+= 1
                decoded = 0
            }

            let symbol = table.findNextSymbol()
            guard symbol != -1
                else { throw BZip2Error.symbolNotFound }
            decoded &+= 1

            if symbol == 0 || symbol == 1 { // RUNA and RUNB symbols.
                runLength &+= repeatPower << symbol
                repeatPower <<= 1
                continue
            }
            if runLength > 0 {
                // There might have been a repeat run right before EOS symbol.
                for _ in 0..<runLength {
                    buffer.append(usedSymbols[0])
                }
                runLength = 0
                repeatPower = 1
            }
            if symbol == usedSymbolsCount - 1 { // End of stream symbol.
                break
            }
            // Move to front inverse.
            let element = usedSymbols.remove(at: symbol - 1)
            usedSymbols.insert(element, at: 0)
            buffer.append(element)
        }

        let nt = BurrowsWheeler.reverse(bytes: buffer, pointer)

        // Run Length Decoding
        var i = 0
        var out = [UInt8]()
        out.reserveCapacity(blockSize.sizeInKilobytes * 1000)
        while i < nt.count {
            if i < nt.count - 4 && nt[i] == nt[i + 1] && nt[i] == nt[i + 2] && nt[i] == nt[i + 3] {
                // While the reference implementation of BZip2 doesn't produce such output, the "specification"
                // technically allows run lengths greater than 255. To allow this we have to convert to Int.
                let runLength = nt[i + 4].toInt() + 4
                for _ in 0..<runLength {
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
