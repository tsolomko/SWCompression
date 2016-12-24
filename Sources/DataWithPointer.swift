//
//  DataWithPointer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 01.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

enum BitOrder {
    case straight
    case reversed
}

final class DataWithPointer {

    let bitOrder: BitOrder
    private let bitArray: [UInt8]
    var index: Int = 0
    private(set) var bitMask: UInt8

    init(array: inout [UInt8], bitOrder: BitOrder) {
        self.bitOrder = bitOrder
        self.bitArray = array

        switch self.bitOrder {
        case .reversed:
            self.bitMask = 1
        case .straight:
            self.bitMask = 128
        }
    }

    convenience init(data: Data, bitOrder: BitOrder) {
        var array = data.toArray(type: UInt8.self)
        self.init(array: &array, bitOrder: bitOrder)
    }

    func bits(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }

        var array: [UInt8] = Array(repeating: 0, count: count)
        for i in 0..<count {
            array[i] = self.bitArray[self.index] & self.bitMask > 0 ? 1 : 0

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
        guard count > 0 else { return 0 }

        var result = 0
        for i in 0..<count {
            let power: Int
            switch self.bitOrder {
            case .straight:
                power = count - i - 1
            case .reversed:
                power = i
            }

            let bit = self.bitArray[self.index] & self.bitMask > 0 ? 1 : 0
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
        let bit = self.bitArray[self.index] & self.bitMask > 0 ? 1 : 0

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
        return self.bitArray[self.index - 1]
    }

    func alignedBytes(count: Int) -> [UInt8] {
        self.skipUntilNextByte()
        var result: [UInt8] = Array(repeating: 0, count: count)
        for i in 0..<count {
            result[i] = self.bitArray[self.index]
            self.index += 1
        }
        return result
    }

    func intFromAlignedBytes(count: Int) -> Int {
        self.skipUntilNextByte()
        var result = 0
        for i in 0..<count {
            result |= self.bitArray[self.index].toInt() << (8 * i)
            self.index += 1
        }
        return result
    }

    func uint64FromAlignedBytes(count: UInt64) -> UInt64 {
        self.skipUntilNextByte()
        var result: UInt64 = 0
        for i: UInt64 in 0..<count {
            result |= UInt64(self.bitArray[self.index]) << (8 * i)
            self.index += 1
        }
        return result
    }

    func multiByteDecode() throws -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        var i = 1
        var result = self.alignedByte().toInt()
        var bytes: [UInt8] = [result.toUInt8()]
        if result <= 127 {
            return (result, bytes)
        }
        result &= 0x7F
        while self.bitArray[self.index - 1] & 0x80 != 0 {
            let byte = self.alignedByte()
            if i >= 9 || byte == 0x00 {
                throw XZError.MultiByteIntegerError
            }
            bytes.append(byte)
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return (result, bytes)
    }

    // MARK: Manipulations with index and bitShift

    func skipUntilNextByte() {
        switch self.bitOrder {
        case .reversed:
            guard self.bitMask != 1 else { return }
            self.bitMask = 1
        case .straight:
            guard self.bitMask != 128 else { return }
            self.bitMask = 128
        }
        self.index += 1
    }

}
