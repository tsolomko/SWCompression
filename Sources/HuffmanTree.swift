//
//  HuffmanTable.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

class HuffmanTree: CustomStringConvertible {

    struct Constants {
        static let codeLengthOrders: [Int] =
            [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

        /// - Warning: Substract 257 from index!
        static let lengthBase: [Int] =
            [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35,
             43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]

        static let distanceBase: [Int] =
            [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
             257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
             8193, 12289, 16385, 24577]

    }

    var description: String {
        return self.tree.reduce("HuffmanTree:\n") { $0.appending("\($1)\n") }
    }

    private var tree: [HuffmanLength?]
    private let leafCount: Int

    init(bootstrap: [Array<Int>]) {
        // Fills the 'lengths' array with numerous HuffmanLengths from a 'bootstrap'
        var lengths: [HuffmanLength] = []
        var start = bootstrap[0][0]
        var bits = bootstrap[0][1]
        for pair in bootstrap[1..<bootstrap.count] {
            let finish = pair[0]
            let endbits = pair[1]
            if bits > 0 {
                lengths.append(contentsOf:
                    (start..<finish).map { HuffmanLength(code: $0, bits: bits, symbol: nil) })
            }
            start = finish
            bits = endbits
        }
        // Sort the lengths' array to calculate symbols correctly
        lengths.sort()

        func reverse(bits: Int, in symbol: Int) -> Int {
            // Auxiliarly function, which generates reversed order of bits in a number
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

        // Calculates symbols for each length in 'lengths' array
        var loopBits = -1
        var symbol = -1
        for index in 0..<lengths.count {
            symbol += 1
            let length = lengths[index]
            // We sometimes need to make symbol to have length.bits bit length
            if length.bits != loopBits {
                symbol <<= (length.bits - loopBits)
                loopBits = length.bits
            }
            lengths[index].symbol = reverse(bits: loopBits, in: symbol)
        }

        // Calculate maximum amount of leaves possible in a tree
        self.leafCount = Int(pow(Double(2), Double(lengths.last!.bits + 1)))
        // Create a tree (array, actually) with all leaves equal nil
        self.tree = Array(repeating: nil, count: leafCount)

        // Populate necessary leaves with HuffmanLengths
        for length in lengths {
            var symbol = length.symbol!
            let bits = length.bits
            var index = 0
            for _ in 0..<bits {
                let bit = symbol & 1
                index = bit == 0 ? 2 * index + 1 : 2 * index + 2
                symbol >>= 1
            }
            self.tree[index] = length
        }
    }

    convenience init(lengthsToOrder: [Int]) {
        var addedLengths = lengthsToOrder
        addedLengths.append(-1)
        let lengthsCount = addedLengths.count
        let range = Array(0...lengthsCount)
        self.init(bootstrap: (zip(range, addedLengths)).map { [$0, $1] })
    }

    func findNextSymbol(in pointerData: DataWithPointer) -> HuffmanLength? {
        var index = 0
        while true {
            let bit = pointerData.bit()
            index = bit == 0 ? 2 * index + 1 : 2 * index + 2
            guard index < self.leafCount else { return nil }
            if let length = self.tree[index] {
                return length
            }
        }
    }

}
