//
//  HuffmanTree.swift
//  SWCompression
//
//  Created by Timofey Solomko on 24.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

class HuffmanTree {

    private enum HTNode {
        case leaf(Int)
        case branch(Set<Int>)
    }

    private var pointerData: DataWithPointer

    private var tree: [HTNode]
    private let leafCount: Int

    private let coding: Bool

    init(bootstrap: [[Int]], _ pointerData: inout DataWithPointer, _ coding: Bool = false) {
        self.coding = coding
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
        self.tree = Array(repeating: .leaf(-1), count: leafCount)

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
            self.tree[index] = .leaf(length[0])
        }

        if coding {
            for treeIndex in stride(from: self.leafCount - 1, through: 0, by: -1) {
                switch self.tree[treeIndex] {
                case .leaf(let symbol):
                    if symbol == -1 {
                        var replacementArray = Set<Int>()

                        let leftChildIndex = 2 * treeIndex + 1
                        if leftChildIndex < self.leafCount {
                            switch self.tree[leftChildIndex] {
                            case .leaf(let leftSymbol):
                                replacementArray.insert(leftSymbol)
                            case .branch(let leftArray):
                                for leftChild in leftArray {
                                    replacementArray.insert(leftChild)
                                }
                            }
                        }

                        let rightChildIndex = 2 * treeIndex + 2
                        if rightChildIndex < self.leafCount {
                            switch self.tree[rightChildIndex] {
                            case .leaf(let rightSymbol):
                                replacementArray.insert(rightSymbol)
                            case .branch(let rightArray):
                                for rightChild in rightArray {
                                    replacementArray.insert(rightChild)
                                }
                            }
                        }

                        self.tree[treeIndex] = .branch(replacementArray)
                    }
                default:
                    continue
                }
            }
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
            switch self.tree[index] {
            case .leaf(let symbol):
                if symbol > -1 {
                    return symbol
                }
            default:
                continue
            }
        }
    }

    func code(symbol: Int, _ bitWriter: inout BitToByteWriter) {
        precondition(self.coding, "HuffmanTree is not initalized for coding!")

        var index = 0
        while true {
            switch self.tree[index] {
            case .leaf(let foundSymbol):
                if foundSymbol == symbol {
                    return
                } else {
                    fatalError("Symbol not found, this error should be replaced with Error.")
                }
            case .branch:
                let leftChildIndex = 2 * index + 1
                if leftChildIndex < self.leafCount {
                    switch self.tree[leftChildIndex] {
                    case .leaf(let foundLeftSymbol):
                        if foundLeftSymbol == symbol {
                            index = leftChildIndex
                            bitWriter.write(bit: 0)
                            continue
                        } else {
                            break
                        }
                    case .branch(let leftArray):
                        if leftArray.contains(symbol) {
                            index = leftChildIndex
                            bitWriter.write(bit: 0)
                            continue
                        } else {
                            break
                        }
                    }
                }

                let rightChildIndex = 2 * index + 2
                if rightChildIndex < self.leafCount {
                    switch self.tree[rightChildIndex] {
                    case .leaf(let foundRightSymbol):
                        if foundRightSymbol == symbol {
                            index = rightChildIndex
                            bitWriter.write(bit: 1)
                            continue
                        } else {
                            fatalError("Symbol not found, this error should be replaced with Error.")
                        }
                    case .branch(let rightArray):
                        if rightArray.contains(symbol) {
                            index = rightChildIndex
                            bitWriter.write(bit: 1)
                            continue
                        } else {
                            fatalError("Symbol not found, this error should be replaced with Error.")
                        }
                    }
                }
            }
        }
    }

}
