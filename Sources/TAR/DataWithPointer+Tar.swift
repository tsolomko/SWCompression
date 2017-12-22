// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension ByteReader {

    private func buffer(_ cutoff: Int, endingWith ends: UInt8...) -> [UInt8] {
        let startIndex = index
        var buffer = [UInt8]()
        while index - startIndex < cutoff {
            let byte = self.byte()
            if ends.contains(byte) {
                index -= 1
                break
            }
            buffer.append(byte)
        }
        index += cutoff - (index - startIndex)
        return buffer
    }

    func nullEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.buffer(cutoff, endingWith: 0), encoding: .ascii) {
            return string
        } else {
            throw TarError.wrongField
        }
    }

    func nullSpaceEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.self.buffer(cutoff, endingWith: 0, 0x20), encoding: .ascii) {
            return string
        } else {
            throw TarError.wrongField
        }
    }

}
