//
//  HuffmanTable.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

struct HuffmanTable: CustomStringConvertible {
    let lengths: [HuffmanLength]

    var description: String {
        return lengths.reduce("HuffmanTable:\n") { $0.appending("\($1)\n") }
    }

    init(bootstrap: [Array<Int>]) {
        var newLengths: [HuffmanLength] = []
        var start = bootstrap[0][0]
        var bits = bootstrap[0][1]
        for pair in bootstrap[1..<bootstrap.count] {
            let finish = pair[0]
            let endbits = pair[1]
            if bits > 0 {
                newLengths.append(contentsOf:
                    (start..<finish).map { HuffmanLength(code: $0, bits: bits, symbol: nil) })
            }
            start = finish
            bits = endbits
            if endbits == -1 { break } // Probably unnecessary line
        }
        self.lengths = newLengths.sorted()
    }
    
}

struct HuffmanLength: Comparable, CustomStringConvertible {
    let code: Int
    let bits: Int
    var symbol: Int? = nil

    var description: String {
        return "(code: \(code), bits: \(bits), symbol: \(symbol))"
    }


    static func <(left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code < right.code
        } else {
            return left.bits < right.bits
        }
    }

    static func <=(left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code <= right.code
        } else {
            return left.bits <= right.bits
        }
    }

    static func >(left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code > right.code
        } else {
            return left.bits > right.bits
        }
    }

    static func >=(left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code >= right.code
        } else {
            return left.bits >= right.bits
        }
    }

    static func ==(left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code == right.code
        } else {
            return left.bits == right.bits
        }
    }
    
}
