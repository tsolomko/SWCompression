//
//  HuffmanTable.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

struct HuffmanTable: CustomStringConvertible {

    var lengths: [HuffmanLength]

    private var minBits: Int
    private var maxBits: Int

    var description: String {
        return lengths.reduce("HuffmanTable:\n") { $0.appending("\($1)\n") }
    }

    init(bootstrap: [Array<Int>]) {
        // Fills the 'lengths' array with numerous HuffmanLengths from a 'bootstrap'
        // However, it does not calculate symbols or reversedSymbols
        // Also, the array is sorted at the end
        var newLengths: [HuffmanLength] = []
        var start = bootstrap[0][0]
        var bits = bootstrap[0][1]
        for pair in bootstrap[1..<bootstrap.count] {
            let finish = pair[0]
            let endbits = pair[1]
            if bits > 0 {
                newLengths.append(contentsOf:
                    (start..<finish).map { HuffmanLength(code: $0, bits: bits,
                                                         symbol: nil, reversedSymbol: nil) })
            }
            start = finish
            bits = endbits
            if endbits == -1 { break } // PROBABLY UNNECESSARY LINE
        }
        self.lengths = newLengths.sorted()
        self.minBits = 16
        self.maxBits = -1
    }

    mutating func populateHuffmanSymbols() {
        // Calculates symbol and reversedSymbol properties for each length in 'lengths' array
        // This is done with the help of some weird magic
        var bits = -1
        var symbol = -1
        for index in 0..<self.lengths.count {
            symbol += 1
            let length = self.lengths[index]
            if length.bits != bits {
                symbol <<= (length.bits - bits)
                bits = length.bits
            }
            self.lengths[index].symbol = symbol
            self.lengths[index].reversedSymbol = self.reverse(bits: bits, in: symbol)
        }
    }

    mutating func minMaxBits() {
        (self.minBits, self.maxBits) = self.lengths.reduce((16, -1)) {
            (tuple: (Int, Int), length: HuffmanLength) -> (Int, Int) in
            return (min(tuple.0, length.bits), max(tuple.1, length.bits))
        }
    }

    private func reverse(bits: Int, in symbol: Int) -> Int {
        // This is some weird magic
        var a = 1 << 0
        var b = 1 << (bits - 1)
        var z = 0
        for i in stride(from: bits - 1, to: -1, by: -2) {
            z |= (symbol >> i) & a
            z |= (symbol << i) & b
            a <<= 1
            b >>= 1
        }
        return z
    }
}

struct HuffmanLength: Comparable, CustomStringConvertible {
    let code: Int
    let bits: Int
    var symbol: Int? = nil
    var reversedSymbol: Int? = nil

    var description: String {
        return "(code: \(code), bits: \(bits), symbol: \(symbol), " +
        "reversedSymbol: \(reversedSymbol))"
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
