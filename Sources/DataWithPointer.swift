//
//  DataWithPointer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 01.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation
import CoreFoundation

enum BitOrder {
    case straight
    case reversed
}

class DataWithPointer {

    let bitOrder: BitOrder
    let bitVector: CFBitVector
    var index: Int
    var bitShift: Int

    init(data: Data, bitOrder: BitOrder) {
        self.index = 0
        self.bitShift = 0
        self.bitOrder = bitOrder
        self.bitVector = CFBitVectorCreate(kCFAllocatorDefault, data.toArray(type: UInt8.self), data.count * 8)
    }

    func bits(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }

        var array: [UInt8] = Array(repeating: 0, count: count)
        for i in 0..<count {
            let currentIndex: Int
            switch self.bitOrder {
            case .straight:
                currentIndex = 8 * index + bitShift
            case .reversed:
                currentIndex = 8 * (index + 1) - bitShift - 1
            }

            array[i] = UInt8(truncatingBitPattern: CFBitVectorGetBitAtIndex(self.bitVector, currentIndex))

            self.bitShift += 1
            if self.bitShift >= 8 {
                self.bitShift = 0
                self.index += 1
            }
        }

        return array
    }

    func intFromBits(count: Int) -> Int {
        guard count > 0 else { return 0 }
        var result = 0
        for i in 0..<count {
            let currentIndex: Int
            let power: Int
            switch self.bitOrder {
            case .straight:
                currentIndex = 8 * index + bitShift
                power = count - i - 1
            case .reversed:
                currentIndex = 8 * (index + 1) - bitShift - 1
                power = i
            }

            result += Int(pow(Double(2), Double(power))) *
                Int(bitPattern: UInt(CFBitVectorGetBitAtIndex(self.bitVector, currentIndex)))

            self.bitShift += 1
            if self.bitShift >= 8 {
                self.bitShift = 0
                self.index += 1
            }
        }

        return result
    }

    func bit() -> UInt8 {
        return self.bits(count: 1).first!
    }

    /// Skips until next byte and returns next `count` bytes.
    func alignedBytes(count: Int) -> [UInt8] {
        self.skipUntilNextByte()
        var array: [UInt8] = Array(repeating: 0, count: count)
        CFBitVectorGetBits(self.bitVector, CFRangeMake(self.index * 8, count * 8), &array)
        self.index += count
        return array
    }

    func alignedByte() -> UInt8 {
        self.skipUntilNextByte()
        var array: [UInt8] = [0]
        CFBitVectorGetBits(self.bitVector, CFRangeMake(self.index * 8, 8), &array)
        self.index += 1
        return array.first!
    }

    // MARK: Manipulations with index and bitShift

    func skipUntilNextByte() {
        guard self.bitShift != 0 else { return }
        self.index += 1
        self.bitShift = 0
    }

    func rewind(bitsCount: Int) {
        let amountOfBytes = (bitsCount - self.bitShift) / 8 + 1
        self.index -= amountOfBytes
        self.bitShift = 8 - (bitsCount - self.bitShift) % 8

        if self.bitShift == 8 {
            self.index += 1
            self.bitShift = 0
        }
    }

}
