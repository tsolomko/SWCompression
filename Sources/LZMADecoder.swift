//
//  LZMADecoder.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

final class LZMADecoder {

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
        var dictionarySize = pointerData.intFromAlignedBytes(count: 4)
        dictionarySize = dictionarySize < (1 << 12) ? 1 << 12 : dictionarySize

        /// Size of uncompressed data. -1 means it is unknown.
        var uncompressedSize = pointerData.intFromAlignedBytes(count: 8)
        uncompressedSize = Double(uncompressedSize) == pow(Double(2), Double(64)) - 1 ? -1 : uncompressedSize


        return Data(bytes: try decodeLZMA(lc, lp, pb, dictionarySize, &uncompressedSize, &pointerData))
    }

    static func decodeLZMA(_ lc: UInt8, _ lp: UInt8, _ pb: UInt8,
                           _ dictionarySize: Int, _ uncompressedSize: inout Int,
                           _ pointerData: inout DataWithPointer) throws -> [UInt8] {
        lzmaInfoPrint("lc: \(lc), lp: \(lp), pb: \(pb), dictionarySize: \(dictionarySize)")
        lzmaInfoPrint("uncompressedSize: \(uncompressedSize)")

        /// An array for storing output data
        var out: [UInt8] = uncompressedSize == -1 ? [] : Array(repeating: 0, count: uncompressedSize)
        var outIndex = uncompressedSize == -1 ? -1 : 0

        let outWindow = LZMAOutWindow(dictSize: dictionarySize)

        guard var rangeDecoder = LZMARangeDecoder(&pointerData) else {
            throw LZMAError.RangeDecoderInitError
        }

        /**
         For literal decoding we need `1 << (lc + lp)` amount of tables.
         Each table contains 0x300 probabilities.
         */
        var literalProbs = Array(repeating: Array(repeating: Constants.probInitValue, count: 0x300),
                                 count: 1 << (lc + lp).toInt())
        // These arrays are used to select type of match or literal.
        var isMatch = Array(repeating: Constants.probInitValue,
                            count: Constants.numStates << Constants.numPosBitsMax)
        var isRep = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRepG0 = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRepG1 = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRepG2 = Array(repeating: Constants.probInitValue, count: Constants.numStates)
        var isRep0Long = Array(repeating: Constants.probInitValue,
                               count: Constants.numStates << Constants.numPosBitsMax)

        var posSlotDecoder: [LZMABitTreeDecoder] = []
        for _ in 0..<Constants.numLenToPosStates {
            posSlotDecoder.append(LZMABitTreeDecoder(numBits: 6))
        }
        let alignDecoder = LZMABitTreeDecoder(numBits: Constants.numAlignBits)
        var posDecoders = Array(repeating: Constants.probInitValue,
                                count: 1 + Constants.numFullDistances - Constants.endPosModelIndex)

        // There are two types of matches so we need two decoders for them.
        let lenDecoder = LZMALenDecoder()
        let repLenDecoder = LZMALenDecoder()

        // These variables represent 'distance history table'.
        var rep0 = 0
        var rep1 = 0
        var rep2 = 0
        var rep3 = 0
        /// Is used to select exact variable from 'IsRep', 'IsRepG0', 'IsRepG1æ and 'IsRepG2' arrays.
        var state = 0

        // Main decoding cycle.
        while true {
            lzmaDiagPrint("=========================")
            lzmaDiagPrint("start_unpackSize: \(uncompressedSize)")
            // If uncompressed size was defined and everything is unpacked then stop.
            if uncompressedSize == 0 {
                if rangeDecoder.isFinishedOK {
                    break
                }
            }

            let posState = outWindow.totalPosition & ((1 << pb.toInt()) - 1)
            lzmaDiagPrint("posState: \(posState)")
            if rangeDecoder.decode(bitWithProb: &isMatch[(state << Constants.numPosBitsMax) + posState], &pointerData) == 0 {
                if uncompressedSize == 0 { throw LZMAError.ExceededUncompressedSize }

                // DECODE LITERAL:
                /// Previous literal (zero, if there was none).
                let prevByte = outWindow.isEmpty ? 0 : outWindow.byte(at: 1)
                lzmaDiagPrint("decodeLiteral_prevByte: \(prevByte)")
                /// Decoded symbol. Initial value is 1.
                var symbol = 1
                /**
                 Index of table with literal probabilities. It is based on the context which consists of:
                 - `lc` high bits of from previous literal. If there were none, i.e. it is the first literal, then this part is skipped.
                 - `lp` low bits from current position in output.
                 */
                let litState = ((outWindow.totalPosition & ((1 << lp.toInt()) - 1)) << lc.toInt()) + (prevByte >> (8 - lc)).toInt()
                // If state is greater than 7 we need to do additional decoding with 'matchByte'.
                if state >= 7 {
                    /**
                     Byte in output at position that is the `distance` bytes before current position,
                     where the `distance` is the distance from the latest decoded match.
                     */
                    var matchByte = outWindow.byte(at: rep0 + 1)
                    repeat {
                        let matchBit = ((matchByte >> 7) & 1).toInt()
                        matchByte <<= 1
                        let bit = rangeDecoder.decode(bitWithProb: &literalProbs[litState][((1 + matchBit) << 8) + symbol], &pointerData)
                        symbol = (symbol << 1) | bit
                        if matchBit != bit {
                            break
                        }
                    } while symbol < 0x100
                }
                while symbol < 0x100 {
                    symbol = (symbol << 1) | rangeDecoder.decode(bitWithProb: &literalProbs[litState][symbol],
                                                                 &pointerData)
                }
                lzmaDiagPrint("decodeLiteral_symbol: \(symbol)")
                let byte = (symbol - 0x100).toUInt8()
                outWindow.put(byte, &out, &outIndex, &uncompressedSize)
                // END.

                // Finally, we need to update `state`.
                if state < 4 {
                    state = 0
                } else if state < 10 {
                    state -= 3
                } else {
                    state -= 6
                }
                lzmaDiagPrint("decodeLiteral_updatedState: \(state)")

                continue
            }

            var len: Int
            if rangeDecoder.decode(bitWithProb: &isRep[state], &pointerData) != 0 {
                // REP MATCH CASE
                if uncompressedSize == 0 { throw LZMAError.ExceededUncompressedSize }
                if outWindow.isEmpty { throw LZMAError.WindowIsEmpty }
                if rangeDecoder.decode(bitWithProb: &isRepG0[state], &pointerData) == 0 {
                    // (We use last distance from 'distance history table').
                    if rangeDecoder.decode(bitWithProb: &isRep0Long[(state << Constants.numPosBitsMax) + posState],
                                           &pointerData) == 0 {
                        // SHORT REP MATCH CASE
                        state = state < 7 ? 9 : 11
                        lzmaDiagPrint("updatedState: \(state)")
                        let byte = outWindow.byte(at: rep0 + 1)
                        lzmaDiagPrint("byte_to_put: \(byte)")
                        outWindow.put(byte, &out, &outIndex, &uncompressedSize)
                        continue
                    }
                } else { // REP MATCH CASE
                    // (It means that we use distance from 'distance history table').
                    // So the following code selectes one distance from history...
                    // based on the binary data.
                    let dist: Int
                    if rangeDecoder.decode(bitWithProb: &isRepG1[state], &pointerData) == 0 {
                        dist = rep1
                    } else {
                        if rangeDecoder.decode(bitWithProb: &isRepG2[state], &pointerData) == 0 {
                            dist = rep2
                        } else {
                            dist = rep3
                            rep3 = rep2
                        }
                        rep2 = rep1
                    }
                    rep1 = rep0
                    rep0 = dist
                    lzmaDiagPrint("rep_match_rep0: \(rep0)")
                    lzmaDiagPrint("rep_match_rep1: \(rep1)")
                    lzmaDiagPrint("rep_match_rep2: \(rep2)")
                    lzmaDiagPrint("rep_match_rep3: \(rep3)")
                    lzmaDiagPrint("rep_match_dist: \(dist)")
                }
                len = repLenDecoder.decode(with: &rangeDecoder, posState: posState, &pointerData)
                lzmaDiagPrint("read_len: \(len)")
                state = state < 7 ? 8 : 11
                lzmaDiagPrint("updatedState: \(state)")
            } else { // SIMPLE MATCH CASE
                // First, we need to move history of distance values.
                rep3 = rep2
                rep2 = rep1
                rep1 = rep0
                len = lenDecoder.decode(with: &rangeDecoder, posState: posState, &pointerData)
                state = state < 7 ? 7 : 10

                lzmaDiagPrint("beforeDecodeDistance_updatedRep3: \(rep3)")
                lzmaDiagPrint("beforeDecodeDistance_updatedRep2: \(rep2)")
                lzmaDiagPrint("beforeDecodeDistance_updatedRep1: \(rep1)")
                lzmaDiagPrint("beforeDecodeDistance_updatedLen: \(len)")
                lzmaDiagPrint("beforeDecodeDistance_updatedState: \(state)")

                // DECODE DISTANCE:
                /// Is used to define context for distance decoding.
                var lenState = len
                if lenState > Constants.numLenToPosStates - 1 {
                    lenState = Constants.numLenToPosStates - 1
                }

                lzmaDiagPrint("decodeDistance_lenState: \(lenState)")

                /// Defines decoding scheme for distance value.
                let posSlot = posSlotDecoder[lenState].decode(with: &rangeDecoder, &pointerData)
                lzmaDiagPrint("decodeDistance_posSlot: \(posSlot)")
                if posSlot < 4 {
                    // If `posSlot` is less than 4 then distance has defined value (no need to decode).
                    // And distance is actually equal to `posSlot`.
                    rep0 = posSlot
                    lzmaDiagPrint("decodeDistance: posSlot => rep0")
                } else {
                    lzmaDiagPrint("decodeDistance: dist => rep0")
                    let numDirectBits = (posSlot >> 1) - 1
                    lzmaDiagPrint("decodeDistance_numDirectBits: \(numDirectBits)")
                    var dist = ((2 | (posSlot & 1)) << numDirectBits)
                    lzmaDiagPrint("decodeDistance_startDist: \(dist)")
                    if posSlot < Constants.endPosModelIndex {
                        // In this case we need a sequence of bits decoded with bit tree...
                        // ...(separate trees for different `posSlot` values)...
                        // ...and 'Reverse' scheme to get distance value.
                        dist += LZMABitTreeDecoder.bitTreeReverseDecode(probs: &posDecoders,
                                                                    startIndex: dist - posSlot,
                                                                    bits: numDirectBits,
                                                                    rangeDecoder: &rangeDecoder,
                                                                    &pointerData)
                        lzmaDiagPrint("decodeDistance_updatedDist_0: \(dist)")
                    } else {
                        // Middle bits of distance are decoded as direct bits from RangeDecoder.
                        dist += rangeDecoder.decode(directBits: (numDirectBits - Constants.numAlignBits),
                                                    &pointerData) << Constants.numAlignBits
                        lzmaDiagPrint("decodeDistance_updatedDist_1_1: \(dist)")
                        // Low 4 bits are decoded with a bit tree decoder (called 'AlignDecoder')...
                        // ...with "Reverse" scheme.
                        dist += alignDecoder.reverseDecode(with: &rangeDecoder, &pointerData)
                        lzmaDiagPrint("decodeDistance_updatedDist_1_2: \(dist)")
                    }
                    rep0 = dist
                }
                // END.

                // Check if finish marker is encountered.
                // Distance value of 2^32 is used to indicate 'End of Stream' marker.
                if rep0 == 0xFFFFFFFF {
                    lzmaDiagPrint("finish_marker")
                    guard rangeDecoder.isFinishedOK else { throw LZMAError.RangeDecoderFinishError }
                    break
                }

                if uncompressedSize == 0 { throw LZMAError.ExceededUncompressedSize }
                if rep0 >= dictionarySize || !outWindow.check(distance: rep0) { throw LZMAError.NotEnoughToRepeat }
            }
            // Converting from zero-based length of the match to the real one.
            len += Constants.matchMinLen
            lzmaDiagPrint("finalLen: \(len)")
            if uncompressedSize > -1 && uncompressedSize < len { throw LZMAError.RepeatWillExceed }
            lzmaDiagPrint("copyMatch_at: \(rep0 + 1)")
            outWindow.copyMatch(at: rep0 + 1, length: len, &out, &outIndex, &uncompressedSize)
        }
        
        return out
    }
    
}

func lzmaDiagPrint(_ s: String) {
    #if LZMA_DIAG
        print(s)
    #endif
}

func lzmaInfoPrint(_ s: String) {
    #if LZMA_INFO
        print(s)
    #endif
}
