//
//  DataWithPointer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 01.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

enum BitOrder {
    case straight
    case reversed
}

class DataWithPointer {

    let bitOrder: BitOrder
    let size: Int
    private let data: Data
    var index: Int = 0
    private(set) var bitMask: UInt8

    var isAtTheEnd: Bool {
        return self.size == self.index
    }

    var prevAlignedByte: UInt8 {
        return self.data[self.index - 1]
    }

    convenience init(array: inout [UInt8], bitOrder: BitOrder) {
        self.init(data: Data(bytes: array), bitOrder: bitOrder)
    }

    init(data: Data, bitOrder: BitOrder) {
        self.bitOrder = bitOrder
        self.size = data.count
        self.data = data
        switch self.bitOrder {
        case .reversed:
            self.bitMask = 1
        case .straight:
            self.bitMask = 128
        }
    }

    func bits(count: Int) -> [UInt8] {
        guard count > 0 else {
            return []
        }

        var array: [UInt8] = Array(repeating: 0, count: count)
        for i in 0..<count {
            array[i] = self.data[self.index] & self.bitMask > 0 ? 1 : 0

            switch self.bitOrder {
            case .reversed:
                if self.bitMask == 128 {
                    self.index += 1
                    self.bitMask = 1
                } else {
                    self.bitMask <<= 1
                }
            case .straight:
                if self.bitMask == 1 {
                    self.index += 1
                    self.bitMask = 128
                } else {
                    self.bitMask >>= 1
                }
            }
        }

        return array
    }

    func intFromBits(count: Int) -> Int {
        guard count > 0 else {
            return 0
        }

        var result = 0
        for i in 0..<count {
            let power: Int
            switch self.bitOrder {
            case .straight:
                power = count - i - 1
            case .reversed:
                power = i
            }

            let bit = self.data[self.index] & self.bitMask > 0 ? 1 : 0
            result += (1 << power) * bit

            switch self.bitOrder {
            case .reversed:
                if self.bitMask == 128 {
                    self.index += 1
                    self.bitMask = 1
                } else {
                    self.bitMask <<= 1
                }
            case .straight:
                if self.bitMask == 1 {
                    self.index += 1
                    self.bitMask = 128
                } else {
                    self.bitMask >>= 1
                }
            }
        }

        return result
    }

    func bit() -> Int {
        let bit = self.data[self.index] & self.bitMask > 0 ? 1 : 0

        switch self.bitOrder {
        case .reversed:
            if self.bitMask == 128 {
                self.index += 1
                self.bitMask = 1
            } else {
                self.bitMask <<= 1
            }
        case .straight:
            if self.bitMask == 1 {
                self.index += 1
                self.bitMask = 128
            } else {
                self.bitMask >>= 1
            }
        }

        return bit
    }

    func alignedByte() -> UInt8 {
        self.skipUntilNextByte()
        self.index += 1
        return self.data[self.index - 1]
    }

    func alignedBytes(count: Int) -> [UInt8] {
        self.skipUntilNextByte()
        var result: [UInt8] = Array(repeating: 0, count: count)
        for i in 0..<count {
            result[i] = self.data[self.index]
            self.index += 1
        }
        return result
    }

    func intFromAlignedBytes(count: Int) -> Int {
        self.skipUntilNextByte()
        var result = 0
        for i in 0..<count {
            result |= self.data[self.index].toInt() << (8 * i)
            self.index += 1
        }
        return result
    }

    func uint64FromAlignedBytes(count: UInt64) -> UInt64 {
        precondition(count <= 8, "UInt64 cannot store more than 8 bytes of data!")
        self.skipUntilNextByte()
        var result: UInt64 = 0
        for i: UInt64 in 0..<count {
            result |= UInt64(self.data[self.index]) << (8 * i)
            self.index += 1
        }
        return result
    }

    func uint32FromAlignedBytes(count: UInt32) -> UInt32 {
        precondition(count <= 4, "UInt32 cannot store more than 4 bytes of data!")
        self.skipUntilNextByte()
        var result: UInt32 = 0
        for i: UInt32 in 0..<count {
            result |= UInt32(self.data[self.index]) << (8 * i)
            self.index += 1
        }
        return result
    }

    // MARK: Manipulations with index and bitShift

    func skipUntilNextByte() {
        switch self.bitOrder {
        case .reversed:
            guard self.bitMask != 1 else {
                return
            }
            self.bitMask = 1
        case .straight:
            guard self.bitMask != 128 else {
                return
            }
            self.bitMask = 128
        }
        self.index += 1
    }

}
