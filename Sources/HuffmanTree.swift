//
//  HuffmanTree.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

class HuffmanTree {

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

        static let lengthCode: [Int] =
            [257, 258, 259, 260, 261, 262, 263, 264, 265, 265, 266, 266, 267, 267, 268, 268,
             269, 269, 269, 269, 270, 270, 270, 270, 271, 271, 271, 271, 272, 272, 272, 272,
             273, 273, 273, 273, 273, 273, 273, 273, 274, 274, 274, 274, 274, 274, 274, 274,
             275, 275, 275, 275, 275, 275, 275, 275, 276, 276, 276, 276, 276, 276, 276, 276,
             277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277, 277,
             278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278, 278,
             279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279, 279,
             280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280, 280,
             281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281,
             281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281, 281,
             282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282,
             282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282, 282,
             283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283,
             283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283, 283,
             284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284,
             284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 284, 285]
    }

    private var pointerData: DataWithPointer

    /// Array of [code, bitsCount] arrays.
    private var tree: [[Int]]
    private let leafCount: Int

    init(bootstrap: [[Int]], _ pointerData: inout DataWithPointer) {
        self.pointerData = pointerData

        // Fills the 'lengths' array with numerous HuffmanLengths from a 'bootstrap'.
        var lengths: [[Int]] = []
        var start = bootstrap[0][0]
        var bits = bootstrap[0][1]
        for pair in bootstrap[1..<bootstrap.count] {
            let finish = pair[0]
            let endbits = pair[1]
            if bits > 0 {
                for i in start..<finish {
                    lengths.append([i, bits])
                }
            }
            start = finish
            bits = endbits
        }
        // Sort the lengths' array to calculate symbols correctly.
        lengths.sort { (left: [Int], right: [Int]) -> Bool in
            if left[1] == right[1] {
                return left[0] < right[0]
            } else {
                return left[1] < right[1]
            }
        }

        func reverse(bits: Int, in symbol: Int) -> Int {
            // Auxiliarly function, which generates reversed order of bits in a number.
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

        // Calculate maximum amount of leaves possible in a tree.
        self.leafCount = 1 << (lengths.last![1] + 1)
        // Create a tree (array, actually) with all leaves equal nil.
        self.tree = Array(repeating: [-1, -1], count: leafCount)

        // Calculates symbols for each length in 'lengths' array and put them in the tree.
        var loopBits = -1
        var symbol = -1
        for length in lengths {
            symbol += 1
            // We sometimes need to make symbol to have length.bits bit length.
            let bits = length[1]
            if bits != loopBits {
                symbol <<= (bits - loopBits)
                loopBits = bits
            }
            // Then we need to reverse bit order of the symbol.
            var treeCode = reverse(bits: loopBits, in: symbol)
            // Finally, we put it at its place in the tree.
            var index = 0
            for _ in 0..<bits {
                let bit = treeCode & 1
                index = bit == 0 ? 2 * index + 1 : 2 * index + 2
                treeCode >>= 1
            }
            self.tree[index] = length
        }
    }

    convenience init(lengthsToOrder: [Int], _ pointerData: inout DataWithPointer) {
        var addedLengths = lengthsToOrder
        addedLengths.append(-1)
        let lengthsCount = addedLengths.count
        let range = Array(0...lengthsCount)
        self.init(bootstrap: (zip(range, addedLengths)).map { [$0, $1] }, &pointerData)
    }

    func findNextSymbol() -> Int {
        var index = 0
        while true {
            let bit = pointerData.bit()
            index = bit == 0 ? 2 * index + 1 : 2 * index + 2
            guard index < self.leafCount else { return -1 }
            if self.tree[index][0] > -1 {
                return self.tree[index][0]
            }
        }
    }

    func code(symbol: Int) -> [UInt8] {
        if var symbolIndex = self.tree.index(where: { $0[0] == symbol }) {
            var bits: [UInt8] = Array(repeating: 0, count: self.tree[symbolIndex][1])
            var i = bits.count - 1
            while symbolIndex > 0 {
                if symbolIndex % 2 == 0 {
                    bits[i] = 1
                    symbolIndex /= 2
                    symbolIndex -= 1
                } else {
                    symbolIndex /= 2
                }
                i -= 1
            }
            return bits
        } else {
            return []
        }
    }

}
