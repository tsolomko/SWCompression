// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class BitWriter {

    private(set) var data = Data()
    private var bitMask: UInt8
    private var currentByte: UInt8 = 0
    private var bitOrder: BitReader.BitOrder

    init(bitOrder: BitReader.BitOrder) {
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
                self.data.append(self.currentByte)
                self.currentByte = 0
            } else {
                self.bitMask <<= 1
            }
        case .straight:
            if self.bitMask == 1 {
                self.bitMask = 128
                self.data.append(self.currentByte)
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
                    self.data.append(self.currentByte)
                    self.currentByte = 0
                } else {
                    self.bitMask <<= 1
                }
            case .straight:
                if self.bitMask == 1 {
                    self.bitMask = 128
                    self.data.append(self.currentByte)
                    self.currentByte = 0
                } else {
                    self.bitMask >>= 1
                }
            }
        }
    }

    func write(number: Int, bitsCount: Int) {
        var mask = self.bitOrder == .straight ? 1 << (bitsCount - 1) : 1
        for _ in 0..<bitsCount {
            self.write(bit: number & mask > 0 ? 1 : 0)
            switch self.bitOrder {
            case .straight:
                mask >>= 1
            case .reversed:
                mask <<= 1
            }
        }
    }

    func align() {
        self.data.append(self.currentByte)
        self.currentByte = 0

        switch self.bitOrder {
        case .reversed:
            self.bitMask = 1
        case .straight:
            self.bitMask = 128
        }
    }

}
