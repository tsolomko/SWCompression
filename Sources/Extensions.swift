//
//  DataExtension.swift
//  SWCompression
//
//  Created by Timofey Solomko on 19.09.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

// TODO: Remove public when release.
public extension Data {

    public func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.pointee }
    }

    public func toArray<T>(type: T.Type) -> [T] {
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
