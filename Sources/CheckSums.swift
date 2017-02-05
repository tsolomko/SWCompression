//
//  CheckSums.swift
//  SWCompression
//
//  Created by Timofey Solomko on 18.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

struct CheckSums {

    private static let crc32table: [UInt32] = {
        var table: [UInt32] = Array(repeating: 0, count: 256)
        let crc32poly: UInt32 = 0xEDB88320 // IEEE
        var r: UInt32 = 0
        var j = 0
        for i in 0..<256 {
            r = UInt32(i)
            j = 8
            while j > 0 {
                r = r & 1 > 0 ? (r >> 1) ^ crc32poly : r >> 1
                j -= 1
            }
            table[i] = UInt32(r)
        }
        return table
    }()

    private static let crc64table: [UInt64] = {
        var table: [UInt64] = Array(repeating: 0, count: 256)
        let crc64poly: UInt64 = 0xC96C5795D7870F42 // ECMA
        var r: UInt64 = 0
        var j = 0
        for i in 0..<256 {
            r = UInt64(i)
            j = 8
            while j > 0 {
                r = r & 1 > 0 ? (r >> 1) ^ crc64poly : r >> 1
                j -= 1
            }
            table[i] = r
        }
        return table
    }()

    static func crc32(_ array: [UInt8], prevValue: UInt32 = 0) -> UInt32 {
        var crc = ~prevValue
        for i in 0..<array.count {
            let index = (crc & 0xFF) ^ (UInt32(array[i]))
            crc = CheckSums.crc32table[Int(index)] ^ (crc >> 8)
        }
        return ~crc
    }

    static func crc64(_ array: [UInt8]) -> UInt64 {
        var crc: UInt64 = ~0
        for i in 0..<array.count {
            let index = (crc & 0xFF) ^ (UInt64(array[i]))
            crc = CheckSums.crc64table[Int(bitPattern: UInt(truncatingBitPattern: index))] ^ (crc >> 8)
        }
        return ~crc
    }

    static func adler32(_ array: [UInt8]) -> Int {
        let base = 65521
        var s1 = 1
        var s2 = 0
        for i in 0..<array.count {
            s1 = (s1 + array[i].toInt()) % base
            s2 = (s2 + s1) % base
        }
        return (s2 << 16) + s1
    }

}
