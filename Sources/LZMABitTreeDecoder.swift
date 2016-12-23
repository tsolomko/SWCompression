//
//  LZMABitTreeDecoder.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/// Used to decode symbols that need several bits for storing.
final class LZMABitTreeDecoder {

    var probs: [Int]
    let numBits: Int

    init(numBits: Int) {
        self.probs = Array(repeating: LZMADecoder.Constants.probInitValue, count: 1 << numBits)
        self.numBits = numBits
    }

    func decode(with rangeDecoder: inout LZMARangeDecoder,
                _ pointerData: inout DataWithPointer) -> Int {
        var m = 1
        for i in 0..<self.numBits {
            m = (m << 1) + rangeDecoder.decode(bitWithProb: &self.probs[m], &pointerData)
            lzmaDiagPrint("bitTreeDecoder_decode_m_\(i): \(m)")
        }
        lzmaDiagPrint("bitTreeDecoder_decode_result: \(m - (1 << self.numBits))")
        return m - (1 << self.numBits)
    }

    func reverseDecode(with rangeDecoder: inout LZMARangeDecoder,
                       _ pointerData: inout DataWithPointer) -> Int {
        lzmaDiagPrint("!!!BitTreeReverseDecode")
        return LZMABitTreeDecoder.bitTreeReverseDecode(probs: &self.probs, startIndex: 0, bits: self.numBits,
                                                   rangeDecoder: &rangeDecoder, &pointerData)
    }

    static func bitTreeReverseDecode(probs: inout [Int], startIndex: Int, bits: Int,
                                     rangeDecoder: inout LZMARangeDecoder,
                                     _ pointerData: inout DataWithPointer) -> Int {
        var m = 1
        var symbol = 0
        for i in 0..<bits {
            let bit = rangeDecoder.decode(bitWithProb: &probs[startIndex + m], &pointerData)
            m <<= 1
            m += bit
            symbol |= bit << i
        }
        return symbol
    }

}
