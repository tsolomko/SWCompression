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

// TODO: Replace all preconditions with guard statements.

final class DataWithPointer {

    let bitOrder: BitOrder
    let size: Int
    private var bitArray: [UInt8]
    var index: Int = 0
    private(set) var bitMask: UInt8

    var isAtTheEnd: Bool {
        return self.size == self.index
    }

    var prevAlignedByte: UInt8 {
        return self.bitArray[self.index - 1]
    }

    init(array: inout [UInt8], bitOrder: BitOrder) {
        self.bitOrder = bitOrder
        self.bitArray = array
        self.size = self.bitArray.count

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

    func intFromAlignedBytes(count: Int) -> Int {
        self.skipUntilNextByte()
        var result = 0
        for i in 0..<count {
            result |= self.bitArray[self.index].toInt() << (8 * i)
            self.index += 1
        }
        return result
    }

    // MARK: Good functions

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

    func uint64FromAlignedBytes(count: Int) -> UInt64 {
        guard count > 0 else { return 0 }
        precondition(count <= 8, "DWP.u64.Bytes: UInt64 cannot store more than 8 bytes.")
        self.skipUntilNextByte()
        var result: UInt64 = 0
        for i in 0..<count {
            result |= UInt64(self.bitArray[self.index]) << (8 * UInt64(i))
            self.index += 1
        }
        return result
    }

    func uint32FromAlignedBytes(count: Int) -> UInt32 {
        guard count > 0 else { return 0 }
        precondition(count <= 4, "DWP.u32.Bytes: UInt32 cannot store more than 4 bytes.")
        self.skipUntilNextByte()
        var result: UInt32 = 0
        for i in 0..<count {
            result |= UInt32(self.bitArray[self.index]) << (8 * UInt32(i))
            self.index += 1
        }
        return result
    }

    func uint16FromAlignedBytes(count: Int) -> UInt16 {
        guard count > 0 else { return 0 }
        precondition(count <= 2, "DWP.u16.Bytes: UInt64 cannot store more than 2 bytes.")
        self.skipUntilNextByte()
        var result: UInt16 = 0
        for i in 0..<count {
            result |= UInt16(self.bitArray[self.index]) << (8 * UInt16(i))
            self.index += 1
        }
        return result
    }

    func uint64FromBits(count: Int) -> UInt64 {
        guard count > 0 else { return 0 }
        precondition(count <= 64, "DWP.u64.bits: UInt64 cannot store more than 64 bits.")

        var result: UInt64 = 0
        for i in 0..<count {
            let power: UInt64
            switch self.bitOrder {
            case .straight:
                power = UInt64(count - i - 1)
            case .reversed:
                power = UInt64(i)
            }

            let bit = self.bitArray[self.index] & self.bitMask > 0 ? 1 : 0
            result += (1 << power) * UInt64(bit)

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

    func uint32FromBits(count: Int) -> UInt32 {
        guard count > 0 else { return 0 }
        precondition(count <= 32, "DWP.u32.bits: UInt32 cannot store more than 32 bits.")

        var result: UInt32 = 0
        for i in 0..<count {
            let power: UInt32
            switch self.bitOrder {
            case .straight:
                power = UInt32(count - i - 1)
            case .reversed:
                power = UInt32(i)
            }

            let bit = self.bitArray[self.index] & self.bitMask > 0 ? 1 : 0
            result += (1 << power) * UInt32(bit)

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

    func uint16FromBits(count: Int) -> UInt16 {
        guard count > 0 else { return 0 }
        precondition(count <= 64, "DWP.u16.bits: UInt16 cannot store more than 16 bits.")

        var result: UInt16 = 0
        for i in 0..<count {
            let power: UInt16
            switch self.bitOrder {
            case .straight:
                power = UInt16(count - i - 1)
            case .reversed:
                power = UInt16(i)
            }

            let bit = self.bitArray[self.index] & self.bitMask > 0 ? 1 : 0
            result += (1 << power) * UInt16(bit)

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
