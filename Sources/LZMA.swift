//
//  LZMA.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during LZMA decompression.
 It may indicate that either the data is damaged or it might not be compressed with LZMA at all.

 - `WrongProperties`: unsupported LZMA properties (greater than 225).
 - `RangeDecoderError`: unable to initialize RanderDecorer.
 */
public enum LZMAError: Error {
    /// Properties byte was greater than 225.
    case WrongProperties
    /// Unable to initialize RanderDecorer.
    case RangeDecoderError
}

/// Provides function to decompress data, which were compressed with LZMA
public final class LZMA: DecompressionAlgorithm {

    struct Constants {
        static let topValue: Int = 1 << 24
        static let numBitModelTotalBits: Int = 11
        static let numMoveBits: Int = 5
        static let probInitValue: Int = ((1 << numBitModelTotalBits) / 2)
        static let numPosBitsMax: Int = 4
        static let numStates: Int = 12
        static let numLenToPosStates: Int = 4
        static let numAlignBits: Int = 4
        static let startPosModelIndex: Int = 4
        static let endPosModelIndex: Int = 14
        static let numFullDistances: Int = (1 << (endPosModelIndex >> 1))
        static let matchMinLen: Int = 2
    }

    final class OutWindow {

        private var byteBuffer: [UInt8]
        private var position: Int
        private var size: Int
        private var isFull: Bool

        private(set) var totalPosition: Int

        var isEmpty: Bool {
            return self.position == 0 && !self.isFull
        }

        init(dictSize: Int) {
            self.byteBuffer = Array(repeating: 0, count: dictSize)
            self.position = 0
            self.totalPosition = 0
            self.size = dictSize
            self.isFull = false
        }

        /// Don't forget to put byte in `out` array.
        func put(byte: UInt8) {
            self.totalPosition += 1
            self.byteBuffer[position] = byte
            self.position += 1
            if self.position == self.size {
                self.position = 0
                self.isFull = true
            }
        }

        func byte(at distance: Int) -> UInt8 {
            return self.byteBuffer[distance <= self.position ? self.position - distance :
                self.size - distance + self.position]
        }

        func copyMatch(at distance: Int, length: Int) {
            for _ in 0..<length {
                self.put(byte: self.byte(at: distance))
            }
        }

        func check(distance: Int) -> Bool {
            return distance <= self.position || self.isFull
        }

    }

    final class RangeDecoder {

        private var range: Int
        private var code: Int
        private(set) var isCorrupted: Bool

        var isFinishedOK: Bool {
            return self.code == 0
        }

        init?(pointerData: inout DataWithPointer) {
            self.isCorrupted = false
            self.range = 0xFFFFFFFF
            self.code = 0

            let byte = pointerData.alignedByte()
            for _ in 0..<4 {
                self.code = (self.code << 8) | pointerData.alignedByte().toInt()
            }
            if byte != 0 || self.code == self.range {
                self.isCorrupted = true
                return nil
            }
        }

        func normalize(pointerData: inout DataWithPointer) {
            if self.range < Constants.topValue {
                self.range <<= 8
                self.code = (self.code << 8) | pointerData.alignedByte().toInt()
            }
        }

        func decode(directBits: Int, pointerData: inout DataWithPointer) -> Int {
            var res = 0
            var count = directBits
            repeat {
                self.range >>= 1
                self.code -= self.range
                let t = 0 - (self.code >> 31)
                self.code += self.range & t

                if self.code == self.range {
                    self.isCorrupted = true
                }

                self.normalize(pointerData: &pointerData)

                res <<= 1
                res += t + 1
                count -= 1
            } while count > 0
            return res
        }

        func decode(bitWithProb prob: inout Int, pointerData: inout DataWithPointer) -> Int {
            let bound = (self.range >> Constants.numBitModelTotalBits) * prob
            let symbol: Int
            if self.code < bound {
                prob += ((1 << Constants.numBitModelTotalBits) - prob) >> Constants.numMoveBits
                self.range = bound
                symbol = 0
            } else {
                prob -= prob >> Constants.numMoveBits
                self.code -= bound
                self.range -= bound
                symbol = 1
            }
            self.normalize(pointerData: &pointerData)
            return symbol
        }

    }

    final class BitTreeDecoder {

        var probs: [Int]
        let numBits: Int

        init(numBits: Int) {
            self.probs = Array(repeating: Constants.probInitValue, count: 1 << numBits)
            self.numBits = numBits
        }

        func decode(with rangeDecoder: RangeDecoder, pointerData: inout DataWithPointer) -> Int {
            var m = 1
            for _ in 0..<self.numBits {
                m = (m << 1) + rangeDecoder.decode(bitWithProb: &self.probs[m], pointerData: &pointerData)
            }
            return m - (1 << self.numBits)
        }

        func reverseDecode(with rangeDecoder: RangeDecoder, pointerData: inout DataWithPointer) -> Int {
            return LZMA.bitTreeReverseDecode(probs: &self.probs, bits: self.numBits, rangeDecoder: rangeDecoder, pointerData: &pointerData)
        }

    }

    static func bitTreeReverseDecode(probs: inout [Int], bits: Int, rangeDecoder: RangeDecoder, pointerData: inout DataWithPointer) -> Int {
        var m = 1
        var symbol = 0
        for i in 0..<bits {
            let bit = rangeDecoder.decode(bitWithProb: &probs[m], pointerData: &pointerData)
            m <<= 1
            m += bit
            symbol |= bit << i
        }
        return symbol
    }

    final class LenDecoder {
        private var choice: Int
        private var choice2: Int
        private var lowCoder: [BitTreeDecoder]
        private var midCoder: [BitTreeDecoder]
        private var highCoder: BitTreeDecoder

        init() {
            self.choice = Constants.probInitValue
            self.choice2 = Constants.probInitValue
            self.highCoder = BitTreeDecoder(numBits: 8)
            self.lowCoder = Array(repeating: BitTreeDecoder(numBits: 3), count: 1 << Constants.numPosBitsMax)
            self.midCoder = Array(repeating: BitTreeDecoder(numBits: 3), count: 1 << Constants.numPosBitsMax)
        }

        func decode(with rangeDecoder: RangeDecoder, posState: Int, pointerData: inout DataWithPointer) -> Int {
            if rangeDecoder.decode(bitWithProb: &self.choice, pointerData: &pointerData) == 0 {
                return self.lowCoder[posState].decode(with: rangeDecoder, pointerData: &pointerData)
            }
            if rangeDecoder.decode(bitWithProb: &self.choice2, pointerData: &pointerData) == 0 {
                return 8 + self.midCoder[posState].decode(with: rangeDecoder, pointerData: &pointerData)
            }
            return 16 + self.highCoder.decode(with: rangeDecoder, pointerData: &pointerData)
        }

    }

    /**
     Decompresses `compressedData` with LZMA algortihm.

     If data passed is not actually compressed with LZMA, `LZMAError` will be thrown.

     - Parameter compressedData: Data compressed with LZMA.

     - Throws: `LZMAError` if unexpected byte (bit) sequence was encountered in `compressedData`.
     It may indicate that either the data is damaged or it might not be compressed with LZMA at all.

     - Returns: Decompressed data.
     */
    public static func decompress(compressedData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        return try decompress(pointerData: &pointerData)
    }

    static func decompress(pointerData: inout DataWithPointer) throws -> Data {

        // First byte contains lzma properties.
        var properties = pointerData.alignedByte()
        if properties >= (9 * 5 * 5) {
            throw LZMAError.WrongProperties
        }
        /// The number of literal context bits
        let lc = properties % 9
        properties /= 9
        /// The number of pos bits
        let pb = properties / 5
        /// The number of literal pos bits
        let lp = properties % 5
        var dictionarySize = pointerData.intFromAlingedBytes(count: 4)
        dictionarySize = dictionarySize < (1 << 12) ? 1 << 12 : dictionarySize

        print("lc: \(lc), lp: \(lp), pb: \(pb), dictionarySize: \(dictionarySize)")

        /// Size of uncompressed data. -1 means it is unknown.
        var uncompressedSize = pointerData.intFromAlingedBytes(count: 8)
        uncompressedSize = Double(uncompressedSize) == pow(Double(2), Double(64)) - 1 ? -1 : uncompressedSize

        /// An array for storing output data
        var out: [UInt8] = uncompressedSize == -1 ? [] : Array(repeating: 0, count: uncompressedSize)
        var outIndex = uncompressedSize == -1 ? -1 : 0

        print("uncompressedSize: \(uncompressedSize)")

        let outWindow = OutWindow(dictSize: dictionarySize)

        guard let rangeDecoder = RangeDecoder(pointerData: &pointerData) else {
            throw LZMAError.RangeDecoderError
        }

        var literalProbs = Array(repeating: Constants.probInitValue, count: 0x300 << (lc + lp).toInt())
        var isMatch = Array(repeating: Constants.probInitValue,
                            count: Constants.numStates << Constants.numPosBitsMax)
        var isRep = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRepG0 = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRepG1 = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRepG2 = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRep0Long = Array(repeating: Constants.probInitValue,
                               count: Constants.numStates << Constants.numPosBitsMax)

        var posSlotDecoder = Array(repeating: BitTreeDecoder(numBits: 6), count: Constants.numLenToPosStates)
        var alignDecoder = BitTreeDecoder(numBits: Constants.numAlignBits)
        var posDecoders = Array(repeating: Constants.probInitValue, count: 1 + Constants.numFullDistances - Constants.endPosModelIndex)

        var lenDecoder = LenDecoder()
        var repLenDecoder = LenDecoder()

        var rep0 = 0
        var rep1 = 0
        var rep2 = 0
        var rep3 = 0
        var state = 0

        func decodeLiteral(_ state: Int, _ rep0: Int) {
            let prevByte = outWindow.isEmpty ? 0 : outWindow.byte(at: 1)
            // TODO: Something is not quite right.
            var symbol = 1
            let litState = ((outWindow.totalPosition & ((1 << lp.toInt()) - 1)) << lc.toInt()) + (prevByte >> (8 - lc)).toInt()
            let probsIndex = 0x300 * litState
            if state >= 7 {
                var matchByte = outWindow.byte(at: rep0 + 1)
                repeat {
                    let matchBit = ((matchByte >> 7) & 1).toInt()
                    matchByte <<= 1
                    let bit = rangeDecoder.decode(bitWithProb: &literalProbs[((1 + matchBit) << 8) + symbol],
                                                  pointerData: &pointerData)
                    symbol = (symbol << 1) | bit
                    if matchBit != bit {
                        break
                    }
                } while symbol < 0x100
            }
            while symbol < 0x100 {
                symbol = (symbol << 1) | rangeDecoder.decode(bitWithProb: &literalProbs[symbol], pointerData: &pointerData)
            }
            let byte = (symbol - 0x100).toUInt8()
            outWindow.put(byte: byte)
            if uncompressedSize > 0 {
                out[outIndex] = byte
                outIndex += 1
            } else {
                out.append(byte)
            }
        }

        func decodeDistance(_ len: Int) -> Int {
            var lenState = len
            if lenState > Constants.numLenToPosStates - 1 {
                lenState = Constants.numLenToPosStates - 1
            }

            let posSlot = posSlotDecoder[lenState].decode(with: rangeDecoder, pointerData: &pointerData)
            if posSlot < 4 {
                return posSlot
            }

            let numDirectBits = (posSlot >> 1) - 1
            var dist = ((2 | (posSlot & 1)) << numDirectBits)
            if posSlot < Constants.endPosModelIndex {
                // TODO: Probably incorrect first argument.
                dist += bitTreeReverseDecode(probs: &posDecoders, bits: numDirectBits, rangeDecoder: rangeDecoder, pointerData: &pointerData)
            } else {
                dist += rangeDecoder.decode(directBits: (numDirectBits - Constants.numAlignBits) << Constants.numAlignBits,
                                            pointerData: &pointerData)
                dist += alignDecoder.reverseDecode(with: rangeDecoder, pointerData: &pointerData)
            }
            return dist
        }

        // Main decoding cycle.
        while true {
            // If uncompressed size was defined and everything is unpacked then stop.
            if uncompressedSize == 0 {
                if rangeDecoder.isFinishedOK {
                    break
                }
            }

            let posState = outWindow.totalPosition & ((1 << pb.toInt()) - 1)
            if rangeDecoder.decode(bitWithProb: &isMatch[(state << Constants.numPosBitsMax) + posState], pointerData: &pointerData) == 0 {
                if uncompressedSize == 0 {
                    // TODO: throw error
                }
                decodeLiteral(state, rep0)
                if state < 4 {
                    state = 0
                } else if (state < 10) {
                    state -= 3
                } else {
                    state -= 6
                }
                uncompressedSize -= 1
                continue
            }

            var len: Int
            if rangeDecoder.decode(bitWithProb: &isRep[state], pointerData: &pointerData) != 0 {
                if uncompressedSize == 0 {
                    // TODO: throw error
                }
                if outWindow.isEmpty {
                    // TODO: throw error
                }
                if rangeDecoder.decode(bitWithProb: &isRepG0[state], pointerData: &pointerData) == 0 {
                    if rangeDecoder.decode(bitWithProb: &isRep0Long[(state << Constants.numPosBitsMax) + posState],
                                           pointerData: &pointerData) == 0 {
                        state = state < 7 ? 9 : 11
                        let byte = outWindow.byte(at: rep0 + 1)
                        outWindow.put(byte: byte)
                        if uncompressedSize > 0 {
                            out[outIndex] = byte
                            outIndex += 1
                        } else {
                            out.append(byte)
                        }
                        uncompressedSize -= 1
                        continue
                    }
                } else {
                    let dist: Int
                    if rangeDecoder.decode(bitWithProb: &isRepG1[state], pointerData: &pointerData) == 0 {
                        dist = rep1
                    } else {
                        if rangeDecoder.decode(bitWithProb: &isRepG2[state], pointerData: &pointerData) == 0 {
                            dist = rep2
                        } else {
                            dist = rep3
                            rep3 = rep2
                        }
                        rep2 = rep1
                    }
                    rep1 = rep0
                    rep0 = dist
                }
                len = repLenDecoder.decode(with: rangeDecoder, posState: posState, pointerData: &pointerData)
                state = state < 7 ? 8 : 11
            } else {
                rep3 = rep2
                rep2 = rep1
                rep1 = rep0
                len = lenDecoder.decode(with: rangeDecoder, posState: posState, pointerData: &pointerData)
                state = state < 7 ? 7 : 10
                rep0 = decodeDistance(len)
                // Check if finished marker is encoutered.
                if rep0 == 0xFFFFFFFF {
                    if rangeDecoder.isFinishedOK {
                        break
                    } else {
                        // TODO: throw error.
                    }
                }

                if uncompressedSize == 0 {
                    // TODO: throw error.
                }
                if rep0 >= dictionarySize || !outWindow.check(distance: rep0) {
                    // TODO: throw error.
                }
            }
            len += Constants.matchMinLen
            var isError = false
            if uncompressedSize > -1 && uncompressedSize < len {
                len = uncompressedSize
                isError = true
            }
            outWindow.copyMatch(at: rep0 + 1, length: len)
            uncompressedSize -= len
            if isError {
                // TODO: throw error.
            }

        }

        return Data(bytes: out)
    }
    
}
