// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Data {

    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }

    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count / MemoryLayout<T>.size))
        }
    }

}

extension UInt8 {

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

}

extension UInt16 {

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

}

extension UInt32 {

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

    func reverseBytes() -> UInt32 {
        var result: UInt32 = 0
        for i: UInt32 in 0..<4 {
            let byte = (self & (0xFF << (i * 8))) >> (i * 8)
            result += byte << (8 * (3 - i))
        }
        return result
    }

}

extension UInt64 {

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

}

extension Int {

    func toUInt8() -> UInt8 {
        return UInt8(truncatingBitPattern: UInt(self))
    }

}
