// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class HuffmanTree {

    private var bitReader: BitReader

    private var tree: [Int]
    private let leafCount: Int

    private var codingIndices: [[Int]]
    private let coding: Bool

    init(bootstrap: [[Int]], _ bitReader: BitReader, _ coding: Bool = false) {
        self.coding = coding
        self.bitReader = bitReader

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
        self.tree = Array(repeating: -1, count: leafCount)

        self.codingIndices = coding ? Array(repeating: [-1, -1], count: lengths.count) : []

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

            if coding {
                self.codingIndices[length[0]] = [treeCode, bits]
            }

            // Finally, we put it at its place in the tree.
            var index = 0
            for _ in 0..<bits {
                let bit = treeCode & 1
                index = bit == 0 ? 2 * index + 1 : 2 * index + 2
                treeCode >>= 1
            }
            self.tree[index] = length[0]
        }
    }

    convenience init(lengthsToOrder: [Int], _ bitReader: BitReader) {
        var addedLengths = lengthsToOrder
        addedLengths.append(-1)
        let lengthsCount = addedLengths.count
        let range = Array(0...lengthsCount)
        self.init(bootstrap: (zip(range, addedLengths)).map { [$0, $1] }, bitReader)
    }

    func findNextSymbol() -> Int {
        var index = 0
        while true {
            let bit = bitReader.bit()
            index = bit == 0 ? 2 * index + 1 : 2 * index + 2
            guard index < self.leafCount else {
                return -1
            }
            if self.tree[index] > -1 {
                return self.tree[index]
            }
        }
    }

    func code(symbol: Int, _ bitWriter: BitWriter, _ symbolNotFoundError: Error) throws {
        precondition(self.coding, "HuffmanTree is not initalized for coding!")

        guard symbol < self.codingIndices.count
            else { throw symbolNotFoundError }

        let codingIndex = self.codingIndices[symbol]

        guard codingIndex[0] > -1
            else { throw symbolNotFoundError }

        var treeCode = codingIndex[0]
        let bits = codingIndex[1]

        for _ in 0..<bits {
            let bit = treeCode & 1
            bitWriter.write(bit: bit == 0 ? 0 : 1)
            treeCode >>= 1
        }
    }

}
