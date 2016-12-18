//
//  CheckSums.swift
//  SWCompression
//
//  Created by Timofey Solomko on 18.12.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

struct CheckSums {

    static let crc32table: [UInt32] = {
        var table: [UInt32] = Array(repeating: 0, count: 256)
        let crc32poly = 0xEDB88320
        var r = 0
        var j = 0
        for i in 0..<256 {
            r = i
            j = 8
            while j > 0 {
                r = r & 1 > 0 ? (r >> 1) ^ crc32poly : r >> 1
                j -= 1
            }
            table[i] = UInt32(r)
        }
        return table
    }()

    static func crc32(_ array: [UInt8]) -> Int {
        var crc: UInt32 = ~0
        for i in 0..<array.count {
            let index = (Int(crc) & 0xFF) ^ (array[i].toInt())
            crc = CheckSums.crc32table[index] ^ (crc >> 8)
        }
        return Int(~crc)
    }
    
}
