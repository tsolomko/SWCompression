// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

// BZip2 specific function for generation of HuffmanLength array from stats.
extension BZip2 {

    /**
     Based on "procedure for generating the lists which specify a Huffman code table" (annexes C and K)
     from Recommendation T.81 of ITU (aka JPEG specfications).
     */
    static func lengths(from stats: [Int]) -> [HuffmanLength] {
        if stats.count == 0 {
            return []
        } else if stats.count == 1 {
            return [HuffmanLength(symbol: 0, codeLength: 1)]
        }

        /// Mutable copy of input `stats`.
        var stats = stats

        var codeSizes = Array(repeating: 0, count: 259)
        var others = Array(repeating: -1, count: 259)

        while true {
            var c1 = -1
            var minFreq = Int.max
            for i in 0..<stats.count {
                if stats[i] > 0 && stats[i] <= minFreq {
                    minFreq = stats[i]
                    c1 = i
                }
            }

            var c2 = -1
            minFreq = Int.max
            for i in 0..<stats.count {
                if stats[i] > 0 && stats[i] <= minFreq && i != c1 {
                    minFreq = stats[i]
                    c2 = i
                }
            }

            guard c2 >= 0
                else { break }

            stats[c1] += stats[c2]
            stats[c2] = 0

            codeSizes[c1] += 1
            while others[c1] >= 0 {
                c1 = others[c1]
                codeSizes[c1] += 1

            }
            others[c1] = c2

            codeSizes[c2] += 1
            while others[c2] >= 0 {
                c2 = others[c2]
                codeSizes[c2] += 1
            }
        }

        // Now we count code lengths.
        // In worst case scenario the maximum code length is 258.
        var bits = Array(repeating: 0, count: 259)
        for i in 0..<bits.count {
            // We don't check for zero code length because we have unused element in `bits` array for them.
            bits[codeSizes[i]] += 1
        }

        // Adjust_bits
        for i in stride(from: 258, to: 20, by: -1) {
            while bits[i] > 0 {
                var j = i - 2
                while bits[j] == 0 {
                    j -= 1
                }
                bits[i] -= 2
                bits[i - 1] += 1
                bits[j + 1] += 2
                bits[j] -= 1
            }
        }

        // Generate_size_table
        var symbol = 0
        var lengths = [HuffmanLength]()
        for i in 1...20 {
            var j = 1
            while j <= bits[i] {
                lengths.append(HuffmanLength(symbol: symbol, codeLength: i))
                symbol += 1
                j += 1
            }
        }

        return lengths
    }

}
