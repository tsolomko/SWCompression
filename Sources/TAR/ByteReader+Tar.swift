// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

extension ByteReader {

    private func buffer(_ cutoff: Int, endingWith ends: UInt8...) -> [UInt8] {
        let startIndex = offset
        var buffer = [UInt8]()
        while offset - startIndex < cutoff {
            let byte = self.byte()
            guard !ends.contains(byte)
                else { break }
            buffer.append(byte)
        }
        offset = startIndex + cutoff
        return buffer
    }

    func nullEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.buffer(cutoff, endingWith: 0), encoding: .utf8) {
            return string
        } else {
            throw TarError.wrongField
        }
    }

    /**
     Reads an `Int` field from TAR container. The end of the field is defined by either:
     1. NULL or SPACE (in containers created by certain old implementations) character.
     2. Reaching specified maximum length.

     Integers are encoded in TAR as ASCII text. We are treating them as UTF-8 encoded strings since UTF-8 is backwards
     compatible with ASCII.

     Integers can also be encoded as non-decimal based number. This is controlled by `radix` parameter.
     */
    func tarInt(maxLength: Int, radix: Int = 10) -> Int? {
        guard let string = String(bytes: self.buffer(maxLength, endingWith: 0, 0x20), encoding: .utf8)
            else { return nil }
        return Int(string, radix: radix)
    }

}
