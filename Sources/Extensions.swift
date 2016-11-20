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

    func bytes(from range: Range<Data.Index>) -> [UInt8] {
        return self.subdata(in: range).toArray(type: UInt8.self)
    }

}

extension UInt8 {

    subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < 8, "Index must be between 0 and 7 (included).")
        let uindex = index.toUInt8()
        return (self & (0x1 << uindex)) >> uindex
    }

    subscript(range: CountableRange<Int>) -> [UInt8] {
        return range.map {
            let uindex = $0.toUInt8()
            return (self & (0x1 << uindex)) >> uindex
        }
    }

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

    func toUintArray() -> [UInt8] {
        return self[0..<8]
    }

    func reversedBitOrder() -> UInt8 {
        var c = (self & 0xF0) >> 4 | (self & 0x0F) << 4
        c = (c & 0xCC) >> 2 | (c & 0x33) << 2
        c = (c & 0xAA) >> 1 | (c & 0x55) << 1
        return c
    }

}

extension UInt16 {

    subscript(range: CountableRange<Int>) -> [UInt8] {
        return range.map {
            let uindex = UInt16(truncatingBitPattern: UInt($0))
            return ((self & (0x1 << uindex)) >> uindex).toUInt8()
        }
    }

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

    func toUInt8() -> UInt8 {
        return UInt8(truncatingBitPattern: self)
    }

}

extension Int {

    func toUInt16() -> UInt16 {
        return UInt16(truncatingBitPattern: UInt(self))
    }

    func toUInt8() -> UInt8 {
        return UInt8(truncatingBitPattern: UInt(self))
    }

}

func convertToInt(uint8Array array: [UInt8], bitOrder: BitOrder = .reversed) -> Int {
    var result = 0
    for i in 0..<array.count {
        let power: Int
        switch bitOrder {
        case .straight:
            power = array.count - i - 1
        case .reversed:
            power = i
        }
        result += Int(pow(Double(2), Double(power))) * Int(bitPattern: UInt(array[i]))
    }
    return result
}

func convertToUInt8(uint8Array array: [UInt8]) -> UInt8 {
    precondition(array.count <= 8, "Array must contain no more than 8 bits.")
    var result: UInt8 = 0
    for i in 0..<array.count {
        result += UInt8(pow(Double(2), Double(i))) * array[i]
    }
    return result
}