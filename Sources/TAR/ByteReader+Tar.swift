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

    func nullSpaceEndedAsciiString(cutoff: Int) throws -> String {
        if let string = String(bytes: self.self.buffer(cutoff, endingWith: 0, 0x20), encoding: .utf8) {
            return string
        } else {
            throw TarError.wrongField
        }
    }

}
