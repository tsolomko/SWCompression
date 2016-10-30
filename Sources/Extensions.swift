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

    func bits(from start: (byte: Data.Index, bit: Data.Index),
              to end: (byte: Data.Index, bit: Data.Index)) -> [UInt8] {
        guard start != end else { return [] }
        let bitsFromData: [UInt8] = Data(self[start.byte...end.byte])
            .toArray(type: UInt8.self).map { $0.reversedBitOrder() }.reversed()
        let bitsArray = bitsFromData.flatMap { $0.toUintArray() }
        let startPoint = bitsArray.count - 8 * (end.byte - start.byte) - end.bit
        let endPoint = bitsArray.count - start.bit
        return Array(bitsArray[startPoint..<endPoint])
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

func convertToInt(reversedUint8Array array: [UInt8]) -> Int {
    var result = 0
    for i in 0..<array.count {
        result += Int(pow(Double(2), Double(i))) * Int(bitPattern: UInt(array[array.count - i - 1]))
    }
    return result
}

func convertToUInt8(reversedUint8Array array: [UInt8]) -> UInt8 {
    precondition(array.count <= 8, "Array must contain no more than 8 bits.")
    var result: UInt8 = 0
    for i in 0..<array.count {
        result += UInt8(pow(Double(2), Double(i))) * array[array.count - i - 1]
    }
    return result
}

func convertToInt(uint8Array array: [UInt8]) -> Int {
    var result = 0
    for i in 0..<array.count {
        result += Int(pow(Double(2), Double(i))) * Int(bitPattern: UInt(array[i]))
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
