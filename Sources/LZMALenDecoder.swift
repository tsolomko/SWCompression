//
//  LZMALenDecoder.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

final class LZMALenDecoder {

    private var pointerData: DataWithPointer

    private var choice: Int
    private var choice2: Int
    private var lowCoder: [LZMABitTreeDecoder]
    private var midCoder: [LZMABitTreeDecoder]
    private var highCoder: LZMABitTreeDecoder

    init(_ pointerData: inout DataWithPointer) {
        self.pointerData = pointerData

        self.choice = LZMADecoder.Constants.probInitValue
        self.choice2 = LZMADecoder.Constants.probInitValue
        self.highCoder = LZMABitTreeDecoder(numBits: 8, &self.pointerData)
        self.lowCoder = []
        self.midCoder = []
        for _ in 0..<(1 << LZMADecoder.Constants.numPosBitsMax) {
            self.lowCoder.append(LZMABitTreeDecoder(numBits: 3, &self.pointerData))
            self.midCoder.append(LZMABitTreeDecoder(numBits: 3, &self.pointerData))
        }
    }

    /// Decodes zero-based match length.
    func decode(with rangeDecoder: inout LZMARangeDecoder, posState: Int) -> Int {
        // There can be one of three options.
        lzmaDiagPrint("!!!LenDecoder_DECODE")
        // We need one or two bits to find out which decoding scheme to use.
        // `choice` is used to decode first bit.
        // `choice2` is used to decode second bit.
        // If binary sequence starts with 0 then:
        if rangeDecoder.decode(bitWithProb: &self.choice) == 0 {
            lzmaDiagPrint("lenDecoder_lowCoder_posState: \(posState)")
            return self.lowCoder[posState].decode(with: &rangeDecoder)
        }
        // If binary sequence starts with 1 0 then:
        if rangeDecoder.decode(bitWithProb: &self.choice2) == 0 {
            lzmaDiagPrint("lenDecoder_midCoder_posState: \(posState)")
            return 8 + self.midCoder[posState].decode(with: &rangeDecoder)
        }
        // If binary sequence starts with 1 1 then:
        return 16 + self.highCoder.decode(with: &rangeDecoder)
    }

}
