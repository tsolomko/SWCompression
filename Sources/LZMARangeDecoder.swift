//
//  LZMARangeDecoder.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

final class LZMARangeDecoder {

    private var pointerData: DataWithPointer

    private var range: UInt32 = 0xFFFFFFFF
    private var code: UInt32 = 0
    private(set) var isCorrupted: Bool = false

    var isFinishedOK: Bool {
        return self.code == 0
    }

    init?(_ pointerData: inout DataWithPointer) {
        self.pointerData = pointerData

        let byte = self.pointerData.alignedByte()
        for _ in 0..<4 {
            self.code = (self.code << 8) | UInt32(self.pointerData.alignedByte())
        }
        if byte != 0 || self.code == self.range {
            self.isCorrupted = true
            return nil
        }
    }

    init() {
        self.pointerData = DataWithPointer(data: Data(), bitOrder: .reversed)
        self.range = 0xFFFFFFFF
        self.code = 0
        self.isCorrupted = false
    }

    /// `range` property cannot be smaller than `(1 << 24)`. This function keeps it bigger.
    func normalize() {
        if self.range < UInt32(LZMAConstants.topValue) {
            self.range <<= 8
            self.code = (self.code << 8) | UInt32(pointerData.alignedByte())
        }
    }

    /// Decodes sequence of direct bits (binary symbols with fixed and equal probabilities).
    func decode(directBits: Int) -> Int {
        var res: UInt32 = 0
        var count = directBits
        repeat {
            self.range >>= 1
            self.code = UInt32.subtractWithOverflow(self.code, self.range).0
            let t = UInt32.subtractWithOverflow(0, self.code >> 31).0
            self.code = UInt32.addWithOverflow(self.code, self.range & t).0

            if self.code == self.range {
                self.isCorrupted = true
            }

            self.normalize()

            res <<= 1
            res = UInt32.addWithOverflow(res, UInt32.addWithOverflow(t, 1).0).0
            count -= 1
        } while count > 0
        return Int(res)
    }

    /// Decodes binary symbol (bit) with predicted (estimated) probability.
    func decode(bitWithProb prob: inout Int) -> Int {
        let bound = (self.range >> UInt32(LZMAConstants.numBitModelTotalBits)) * UInt32(prob)
        let symbol: Int
        if self.code < bound {
            prob += ((1 << LZMAConstants.numBitModelTotalBits) - prob) >> LZMAConstants.numMoveBits
            self.range = bound
            symbol = 0
        } else {
            prob -= prob >> LZMAConstants.numMoveBits
            self.code -= bound
            self.range -= bound
            symbol = 1
        }
        self.normalize()
        return symbol
    }

}
