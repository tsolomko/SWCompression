//
//  BitToByteWriter.swift
//  SWCompression
//
//  Created by Timofey Solomko on 03.02.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

final class BitToByteWriter {

    private(set) var buffer: [UInt8] = []
    private var bitMask: UInt8
    private var currentByte: UInt8 = 0
    private var bitOrder: BitOrder

    init(bitOrder: BitOrder) {
        self.bitOrder = bitOrder

        switch self.bitOrder {
        case .reversed:
            self.bitMask = 1
        case .straight:
            self.bitMask = 128
        }
    }

    func write(bit: UInt8) {
        precondition(bit <= 1, "A bit must be either 0 or 1.")

        self.currentByte += self.bitMask * bit

        switch self.bitOrder {
        case .reversed:
            if self.bitMask == 128 {
                self.bitMask = 1
                self.buffer.append(self.currentByte)
                self.currentByte = 0
            } else {
                self.bitMask <<= 1
            }
        case .straight:
            if self.bitMask == 1 {
                self.bitMask = 128
                self.buffer.append(self.currentByte)
                self.currentByte = 0
            } else {
                self.bitMask >>= 1
            }
        }
    }

    func write(bits: [UInt8]) {
        for bit in bits {
            precondition(bit <= 1, "A bit must be either 0 or 1.")

            self.currentByte += self.bitMask * bit

            switch self.bitOrder {
            case .reversed:
                if self.bitMask == 128 {
                    self.bitMask = 1
                    self.buffer.append(self.currentByte)
                    self.currentByte = 0
                } else {
                    self.bitMask <<= 1
                }
            case .straight:
                if self.bitMask == 1 {
                    self.bitMask = 128
                    self.buffer.append(self.currentByte)
                    self.currentByte = 0
                } else {
                    self.bitMask >>= 1
                }
            }
        }
    }

    func write(number: Int, bitsCount: Int) {
        var mask = 1
        for _ in 0..<bitsCount {
            if number & mask > 0 {
                self.write(bit: 1)
            } else {
                self.write(bit: 0)
            }
            mask <<= 1
        }
    }

    func writeReversed(number: Int, bitsCount: Int) {
        var mask = 1 << bitsCount
        for _ in 0..<bitsCount {
            if number & mask > 0 {
                self.write(bit: 1)
            } else {
                self.write(bit: 0)
            }
            mask >>= 1
        }
    }

    func finish() {
        self.buffer.append(self.currentByte)
        self.currentByte = 0

        switch self.bitOrder {
        case .reversed:
            self.bitMask = 1
        case .straight:
            self.bitMask = 128
        }
    }

}
