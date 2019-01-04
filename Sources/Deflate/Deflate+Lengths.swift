// Copyright (c) 2019 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

// Deflate specific functions for generation of HuffmanLength arrays from different inputs.
extension Deflate {

    static func lengths(from bootstrap: [(symbol: Int, codeLength: Int)]) -> [CodeLength] {
        // Fills the 'lengths' array with pairs of (symbol, codeLength) from a 'bootstrap'.
        var lengths = [CodeLength]()
        var start = bootstrap[0].symbol
        var bits = bootstrap[0].codeLength
        for pair in bootstrap[1..<bootstrap.count] {
            let finish = pair.symbol
            let endbits = pair.codeLength
            if bits > 0 {
                for i in start..<finish {
                    lengths.append(CodeLength(symbol: i, codeLength: bits))
                }
            }
            start = finish
            bits = endbits
        }
        return lengths
    }

    /// - Note: Skips zero codeLengths.
    static func lengths(from orderedCodeLengths: [Int]) -> [CodeLength] {
        var lengths = [CodeLength]()
        for (i, codeLength) in orderedCodeLengths.enumerated() where codeLength > 0 {
            lengths.append(CodeLength(symbol: i, codeLength: codeLength))
        }
        return lengths
    }

}
