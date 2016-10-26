//
//  HuffmanTable.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

class HuffmanTable: CustomStringConvertible {

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
            if endbits == -1 { break } // PROBABLY UNNECESSARY LINE
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
        let bootstrap = (zip(range, addedLengths)).map { [$0, $1] }
        self.init(bootstrap: bootstrap)
    }

    func findNextSymbol(in data: Data, withShift shift: Int, reversed: Bool = true) -> (Int, Int) {
        func convertToInt(uint8Array array: [UInt8]) -> Int {
            var result = 0
            for i in 0..<array.count {
                result += Int(pow(Double(2), Double(i))) * Int(bitPattern: UInt(array[array.count - i - 1]))
            }
            return result
        }

        var bitsFromData = Data(data[0...1]).toArray(type: UInt8.self).map { $0.reversedBitOrder() }
        var bitsArray = bitsFromData[1].toUintArray()
        bitsArray.append(contentsOf: bitsFromData[0].toUintArray())
        let bitsCount = bitsArray.count

        var cachedLength = -1
        var cached: Int = -1

        for length in self.lengths {
            let lbits = length.bits
            let bits = convertToInt(uint8Array:
                Array(bitsArray[bitsCount - lbits - shift..<bitsCount - shift]))

            if cachedLength != lbits {
                cached = bits
                cachedLength = lbits
            }
            if (reversed && length.reversedSymbol == cached) ||
                (!reversed && length.symbol == cached) {
                return (length.code, (lbits <= 8) ? 1 : 2)
            }
        }
        return (-1, -1)
    }
}
