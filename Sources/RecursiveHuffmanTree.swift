// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

enum RecursiveHuffmanTree {
    case leaf(Int)
    indirect case node(RecursiveHuffmanTree, RecursiveHuffmanTree)

    func calculateLengths(_ parentLength: Int = 0) -> [HuffmanLength] {
        var lengths = [HuffmanLength]()
        switch(self) {
        case let .leaf(symbol):
            lengths.append(HuffmanLength(symbol: symbol, codeLength: parentLength + 1))
        case let .node(left, right):
            lengths.append(contentsOf: left.calculateLengths(parentLength + 1))
            lengths.append(contentsOf: right.calculateLengths(parentLength + 1))
        }
        return lengths
    }

    static func build(_ stats: [Int]) -> RecursiveHuffmanTree {
        precondition(stats.count > 0, "Must contain at least one symbol.")

        let leaves = stats.enumerated().sorted { $0.1 < $1.1 }.map { ($1, RecursiveHuffmanTree.leaf($0)) }
        var nodes = [(Int, RecursiveHuffmanTree)]()

        var i = 0
        var j = 0
        while true {
            precondition(i < leaves.count || j < nodes.count)

            var left: (Int, RecursiveHuffmanTree)
            if j == nodes.count || i < leaves.count && leaves[i].0 < nodes[j].0 {
                left = leaves[i]
                i += 1
            } else {
                left = nodes[j]
                j += 1
            }

            if i == leaves.count && j == nodes.count {
                return left.1
            }

            var right: (Int, RecursiveHuffmanTree)
            if j == nodes.count || i < leaves.count && leaves[i].0 < nodes[j].0 {
                right = leaves[i]
                i += 1
            } else {
                right = nodes[j]
                j += 1
            }

            nodes.append((left.0 + right.0, .node(left.1, right.1)))
        }
    }
}
