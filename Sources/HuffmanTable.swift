//
//  HuffmanTable.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

class HuffmanTable: CustomStringConvertible {

    struct Constants {
        static let codeLengthOrders: [Int] =
            [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

        // Substract 257 from index!
        static let lengthBase: [Int] =
            [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35,
             43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]

        static let distanceBase: [Int] =
            [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
             257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
             8193, 12289, 16385, 24577]

        static func extraLengthBits(n: Int) -> Int {
            if (n >= 257 && n <= 256) || n == 285 {
                return 0
            } else if n >= 261 && n <= 284 {
                return ((n - 257) >> 2) - 1
            } else {
                return -1
            }
        }

        static func extraDistanceBits(n: Int) -> Int {
            if n >= 0 && n <= 1 {
                return 0
            } else if n >= 2 && n <= 29 {
                return (n >> 1) - 1
            } else {
                return -1
            }
        }

    }

    var lengths: [HuffmanLength]

    private var minBits: Int
    private var maxBits: Int

    var description: String {
        return self.lengths.reduce("HuffmanTable:\n") { $0.appending("\($1)\n") }
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
            if endbits == -1 { break } // TODO: Check if this line is unnecessary
        }
        self.lengths = newLengths.sorted()

        // Calculates symbols for all lengths in the table
        func reverse(bits: Int, in symbol: Int) -> Int {
            // Auxiliarly subfunction, which computes reversed order of bits in a number
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

        // Calculates symbol and reversedSymbol properties for each length in 'lengths' array
        // This is done with the help of some weird magic
        var loopBits = -1
        var symbol = -1
        for index in 0..<self.lengths.count {
            symbol += 1
            let length = self.lengths[index]
            if length.bits != loopBits {
                symbol <<= (length.bits - loopBits)
                loopBits = length.bits
            }
            self.lengths[index].symbol = symbol
            self.lengths[index].reversedSymbol = reverse(bits: loopBits, in: symbol)
        }

        // Finds minimum and maximum bits in the entire table of lengths
        (self.minBits, self.maxBits) = self.lengths.reduce((16, -1)) {
            return (min($0.0, $1.bits), max($0.1, $1.bits))
        }
    }

    convenience init(lengthsToOrder: [Int]) {
        var addedLengths = lengthsToOrder
        addedLengths.append(-1)
        let lengthsCount = addedLengths.count
        let range = Array(0...lengthsCount)
        self.init(bootstrap: (zip(range, addedLengths)).map { [$0, $1] })
    }

    func findNextSymbol(in data: Data, withShift shift: Int, reversed: Bool = true) ->
        (symbol: Int, addToIndex: Int, newShift: Int) {
        let bitsArray = data.bits(from: (0, shift), to: (1, 8))
        let bitsCount = bitsArray.count

        var cachedLength = -1
        var cached: Int = -1

        for length in self.lengths {
            let lbits = length.bits
            let bits = convertToInt(reversedUint8Array: Array(bitsArray[bitsCount - lbits..<bitsCount]))

            if cachedLength != lbits {
                cached = bits
                cachedLength = lbits
            }
            if (reversed && length.reversedSymbol == cached) ||
                (!reversed && length.symbol == cached) {
                return (length.code,
                        shift + cachedLength < 8 ? 0 : 1,
                        shift + cachedLength < 8 ? shift + cachedLength : shift + cachedLength - 8)
            }
        }
        return (-1, -1, -1)
    }
}
