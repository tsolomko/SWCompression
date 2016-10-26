//
//  DataExtension.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.09.16.
//  Copyright © 2016 tsolomko. All rights reserved.
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

    func byte(at index: Data.Index, withShift shift: Int) -> UInt8 {
        precondition(shift >= 0 && shift < 8, "Shift must be between 0 and 7 (included).")
        let firstPart = self[index]
        let secondPart = self[index + 1]
        let convShift = UInt8(truncatingBitPattern: shift)
        let result: UInt8 = (firstPart << convShift) | (secondPart >> (8 - convShift))
        return result
    }

    func bytes(from range: Range<Data.Index>, withShift shift: Int) -> [UInt8] {
        precondition(shift >= 0 && shift < 8, "Shift must be between 0 and 7 (included).")
        let bytesArray = self.bytes(from: range.lowerBound..<range.upperBound + 1)
        var resultArray: [UInt8] = []
        let convShift = UInt8(truncatingBitPattern: shift)
        for i in range.lowerBound..<range.upperBound + 1 {
            let firstPart = bytesArray[i]
            let secondPart = bytesArray[i + 1]
            resultArray.append((firstPart << convShift) | (secondPart >> (8 - convShift)))
        }
        return resultArray
    }

}

extension UInt8 {

    func combined(withByte second: UInt8) -> UInt16 {
        let result: UInt16 =  UInt16(self) << 8 | UInt16(second)
        return result
    }

    subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < 8, "Index must be between 0 and 7 (included).")
        let uindex = UInt8(truncatingBitPattern: index)
        return (self & (0x1 << uindex)) >> uindex
    }

    subscript(range: CountableRange<Int>) -> [UInt8] {
        return range.map {
            let uindex = UInt8(truncatingBitPattern: $0)
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
            let uindex = UInt16(truncatingBitPattern: $0)
            return UInt8(truncatingBitPattern: (self & (0x1 << uindex)) >> uindex)
        }
    }

    func toInt() -> Int {
        return Int(bitPattern: UInt(self))
    }

}
