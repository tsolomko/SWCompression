// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension DataWithPointer {

    func nullEndedBuffer(cutoff: Int) -> [UInt8] {
        let startIndex = index
        var buffer = [UInt8]()
        while index - startIndex < cutoff {
            let byte = self.byte()
            if byte == 0 {
                index -= 1
                break
            }
            buffer.append(byte)
        }
        index += cutoff - (index - startIndex)
        return buffer
    }

    func nullEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.nullEndedBuffer(cutoff: cutoff), encoding: .ascii) {
            return string
        } else {
            throw TarError.notAsciiString
        }
    }

    func nullSpaceEndedBuffer(cutoff: Int) -> [UInt8] {
        let startIndex = index
        var buffer = [UInt8]()
        while index - startIndex < cutoff {
            let byte = self.byte()
            if byte == 0 || byte == 0x20 {
                index -= 1
                break
            }
            buffer.append(byte)
        }
        index += cutoff - (index - startIndex)
        return buffer
    }

    func nullSpaceEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.nullSpaceEndedBuffer(cutoff: cutoff), encoding: .ascii) {
            return string
        } else {
            throw TarError.notAsciiString
        }
    }

}
