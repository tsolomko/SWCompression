// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension DataWithPointer {

    func multiByteDecode() throws -> Int {
        var i = 1
        var result = self.byte().toInt()
        if result <= 127 {
            return result
        }
        result &= 0x7F
        while self.previousByte & 0x80 != 0 {
            let byte = self.byte()
            if i >= 9 || byte == 0x00 {
                throw XZError.multiByteIntegerError
            }
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return result
    }

}
