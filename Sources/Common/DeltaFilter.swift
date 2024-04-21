// Copyright (c) 2024 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

enum DeltaFilter {

    static func decode(_ byteReader: LittleEndianByteReader, _ distance: Int) -> Data {
        var out = [UInt8]()

        var pos = 0
        var delta = Array(repeating: 0 as UInt8, count: 256)

        while !byteReader.isFinished {
            let byte = byteReader.byte()

            var tmp = delta[(distance + pos) % 256]
            tmp = byte &+ tmp
            delta[pos] = tmp

            out.append(tmp)
            if pos == 0 {
                pos = 255
            } else {
                pos -= 1
            }
        }

        return Data(out)
    }

}
