//
//  HuffmanLength.swift
//  SWCompression
//
//  Created by Timofey Solomko on 26.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

struct HuffmanLength: Comparable, CustomStringConvertible {
    let code: Int
    let bits: Int
    var symbol: Int? = nil

    var description: String {
        return "(code: \(code), bits: \(bits), symbol: \(symbol)"
    }

    static func < (left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code < right.code
        } else {
            return left.bits < right.bits
        }
    }

    static func <= (left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code <= right.code
        } else {
            return left.bits <= right.bits
        }
    }

    static func > (left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code > right.code
        } else {
            return left.bits > right.bits
        }
    }

    static func >= (left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code >= right.code
        } else {
            return left.bits >= right.bits
        }
    }

    static func == (left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.bits == right.bits {
            return left.code == right.code
        } else {
            return left.bits == right.bits
        }
    }

}
