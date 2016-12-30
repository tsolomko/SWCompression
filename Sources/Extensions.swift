//
//  DataExtension.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.09.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

extension Data {

    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }

    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count/MemoryLayout<T>.size))
        }
    }

}

extension UInt8 {

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

}

extension Int {

    func toUInt8() -> UInt8 {
        return UInt8(truncatingBitPattern: UInt(self))
    }

    func reverseBytes() -> Int {
        var result = 0
        for i in 0..<4 {
            let byte = ((self & (0xFF << (i * 8))) >> (i * 8))
            result += byte << (8 * (3 - i))
        }
        return result
    }

}

func +(lhs: UInt8, rhs: UInt16) -> UInt16 {
    return UInt16(lhs) + rhs
}

func +(lhs: UInt16, rhs: UInt8) -> UInt16 {
    return lhs + UInt16(rhs)
}

func +(lhs: UInt8, rhs: UInt32) -> UInt32 {
    return UInt32(lhs) + rhs
}

func +(lhs: UInt32, rhs: UInt8) -> UInt32 {
    return lhs + UInt32(rhs)
}

func +(lhs: UInt8, rhs: UInt64) -> UInt64 {
    return UInt64(lhs) + rhs
}

func +(lhs: UInt64, rhs: UInt8) -> UInt64 {
    return lhs + UInt64(rhs)
}

func +(lhs: UInt16, rhs: UInt32) -> UInt32 {
    return UInt32(lhs) + rhs
}

func +(lhs: UInt32, rhs: UInt16) -> UInt32 {
    return lhs + UInt32(rhs)
}

func +(lhs: UInt16, rhs: UInt64) -> UInt64 {
    return UInt64(lhs) + rhs
}

func +(lhs: UInt64, rhs: UInt16) -> UInt64 {
    return lhs + UInt64(rhs)
}

func +(lhs: UInt32, rhs: UInt64) -> UInt64 {
    return UInt64(lhs) + rhs
}

func +(lhs: UInt64, rhs: UInt32) -> UInt64 {
    return lhs + UInt64(rhs)
}

