// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

typealias HuffmanCodes = (codes: [Code], maxBits: Int)

struct Code {

    /// Number of bits used for `code`.
    let bits: Int
    let code: Int
    let symbol: Int

    static func huffmanCodes(from lengths: [CodeLength]) -> HuffmanCodes {
        // Sort `lengths` array to calculate canonical Huffman code.
        let sortedLengths = lengths.sorted()

        // Calculate maximum amount of leaves possible in a tree.
        let maxBits = sortedLengths.last!.codeLength
        var codes = [Code]()
        codes.reserveCapacity(sortedLengths.count)

        var loopBits = -1
        var symbol = -1
        for length in sortedLengths where length.codeLength > 0 {
            symbol += 1
            // We sometimes need to make symbol to have length.bits bit length.
            let bits = length.codeLength
            if bits != loopBits {
                symbol <<= (bits - loopBits)
                loopBits = bits
            }
            // Then we need to reverse bit order of the symbol.
            let code = symbol.reversed(bits: loopBits)
            codes.append(Code(bits: length.codeLength, code: code, symbol: length.symbol))
        }
        return (codes, maxBits)
    }

}
