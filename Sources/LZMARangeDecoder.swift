//
//  LZMARangeDecoder.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

final class LZMARangeDecoder {

    private var range: UInt32
    private var code: UInt32
    private(set) var isCorrupted: Bool

    var isFinishedOK: Bool {
        return self.code == 0
    }

    init?(_ pointerData: inout DataWithPointer) {
        self.isCorrupted = false
        self.range = 0xFFFFFFFF
        self.code = 0

        let byte = pointerData.alignedByte()
        for _ in 0..<4 {
            self.code = (self.code << 8) | UInt32(pointerData.alignedByte())
        }
        if byte != 0 || self.code == self.range {
            self.isCorrupted = true
            return nil
        }
    }

    /// `range` property cannot be smaller than `(1 << 24)`. This function keeps it bigger.
    func normalize(_ pointerData: inout DataWithPointer) {
        if self.range < UInt32(LZMADecoder.Constants.topValue) {
            self.range <<= 8
            self.code = (self.code << 8) | UInt32(pointerData.alignedByte())
        }
    }

    /// Decodes sequence of direct bits (binary symbols with fixed and equal probabilities).
    func decode(directBits: Int, _ pointerData: inout DataWithPointer) -> Int {
        lzmaDiagPrint("!!!decodeDirectBits")
        lzmaDiagPrint("decodeDirectBits_code_start: \(self.code)")
        lzmaDiagPrint("decodeDirectBits_range_start: \(self.range)")
        var res: UInt32 = 0
        var count = directBits
        lzmaDiagPrint("decodeDirectBits_count: \(count)")
        repeat {
            self.range >>= 1
            lzmaDiagPrint("decodeDirectBits_range_1: \(self.range)")
            self.code = UInt32.subtractWithOverflow(self.code, self.range).0
            lzmaDiagPrint("decodeDirectBits_code_1: \(self.code)")
            let t = UInt32.subtractWithOverflow(0, self.code >> 31).0
            lzmaDiagPrint("decodeDirectBits_t: \(t)")
            self.code = UInt32.addWithOverflow(self.code, self.range & t).0

            if self.code == self.range {
                lzmaDiagPrint("???Corrupted")
                self.isCorrupted = true
            }

            self.normalize(&pointerData)

            res <<= 1
            res = UInt32.addWithOverflow(res, UInt32.addWithOverflow(t, 1).0).0
            count -= 1
        } while count > 0
        return Int(res)
    }

    /// Decodes binary symbol (bit) with predicted (estimated) probability.
    func decode(bitWithProb prob: inout Int, _ pointerData: inout DataWithPointer) -> Int {
        let bound = (self.range >> UInt32(LZMADecoder.Constants.numBitModelTotalBits)) * UInt32(prob)
        lzmaDiagPrint("decodebit")
        lzmaDiagPrint("bound: \(bound)")
        lzmaDiagPrint("probBefore: \(prob)")
        let symbol: Int
        if self.code < bound {
            prob += ((1 << LZMADecoder.Constants.numBitModelTotalBits) - prob) >> LZMADecoder.Constants.numMoveBits
            self.range = bound
            symbol = 0
        } else {
            prob -= prob >> LZMADecoder.Constants.numMoveBits
            self.code -= bound
            self.range -= bound
            symbol = 1
        }
        lzmaDiagPrint("probAfter: \(prob)")
        lzmaDiagPrint("codeAfter: \(self.code)")
        lzmaDiagPrint("rangeAfter: \(self.range)")
        lzmaDiagPrint("-------------------")
        self.normalize(&pointerData)
        return symbol
    }

}
