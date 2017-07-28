// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipPackInfo {

    let packPosition: Int
    let numPackStreams: Int
    private(set) var packSizes = [Int]()
    private(set) var digests = [UInt32?]()

    init(_ bitReader: BitReader) throws {
        packPosition = bitReader.szMbd()
        numPackStreams = bitReader.szMbd()

        var type = bitReader.byte()

        if type == 0x09 {
            for _ in 0..<numPackStreams {
                packSizes.append(bitReader.szMbd())
            }
            type = bitReader.byte()
        }

        if type == 0x0A {
            let allDefined = bitReader.byte()
            let definedBits: [UInt8]
            if allDefined == 0 {
                definedBits = bitReader.bits(count: numPackStreams)
                bitReader.skipUntilNextByte()
            } else {
                definedBits = Array(repeating: 1, count: numPackStreams)
            }

            for bit in definedBits {
                if bit == 1 {
                    digests.append(bitReader.uint32())
                } else {
                    digests.append(nil)
                }
            }
            
            type = bitReader.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

}
