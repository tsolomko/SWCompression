// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct HuffmanLength {

    let symbol: Int
    let codeLength: Int

    static func lengths(from bootStrap: [(symbol: Int, codeLength: Int)]) -> [HuffmanLength] {
        // Fills the 'lengths' array with pairs of (symbol, codeLength) from a 'bootstrap'.
        var lengths = [HuffmanLength]()
        var start = bootStrap[0].symbol
        var bits = bootStrap[0].codeLength
        for pair in bootStrap[1..<bootStrap.count] {
            let finish = pair.symbol
            let endbits = pair.codeLength
            if bits > 0 {
                for i in start..<finish {
                    lengths.append(HuffmanLength(symbol: i, codeLength: bits))
                }
            }
            start = finish
            bits = endbits
        }
        return lengths
    }

    /// - Note: Skips zero codeLengths.
    static func lengths(from orderedCodeLengths: [Int]) -> [HuffmanLength] {
        var lengths = [HuffmanLength]()
        for (i, codeLength) in orderedCodeLengths.enumerated() where codeLength > 0 {
            lengths.append(HuffmanLength(symbol: i, codeLength: codeLength))
        }
        return lengths
    }

}

extension HuffmanLength: Comparable {

    static func <(left: HuffmanLength, right: HuffmanLength) -> Bool {
        if left.codeLength == right.codeLength {
            return left.symbol < right.symbol
        } else {
            return left.codeLength < right.codeLength
        }
    }

    static func ==(left: HuffmanLength, right: HuffmanLength) -> Bool {
        return left.codeLength == right.codeLength && left.symbol == right.symbol
    }

}
