// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension DataWithPointer {

    // TODO: Replace with single DataError.
    func multiByteDecode(_ mbiError: Error) throws -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        var i = 1
        var result = self.byte().toInt()
        var bytes: [UInt8] = [result.toUInt8()]
        if result <= 127 {
            return (result, bytes)
        }
        result &= 0x7F
        while self.previousByte & 0x80 != 0 {
            let byte = self.byte()
            if i >= 9 || byte == 0x00 {
                throw mbiError
            }
            bytes.append(byte)
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return (result, bytes)
    }
    
}

