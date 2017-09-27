// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class BurrowsWheeler {

    static func transform(bytes: [UInt8]) -> ([UInt8], Int) {
        let suffixArray = SuffixArray.make(from: bytes, with: 256)
        var bwt = [UInt8]()
        var pointer = 0
        for i in 1..<suffixArray.count {
            if suffixArray[i] > 0 {
                bwt.append(bytes[suffixArray[i] - 1])
            } else {
                bwt.append(bytes.last!)
                pointer = i - 1
            }
        }
        return (bwt, pointer)
    }

}
