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

    init(_ pointerData: DataWithPointer) throws {
        packPosition = pointerData.szMbd()
        numPackStreams = pointerData.szMbd()

        var type = pointerData.byte()

        if type == 0x09 {
            for _ in 0..<numPackStreams {
                packSizes.append(pointerData.szMbd())
            }
            type = pointerData.byte()
        }

        if type == 0x0A {
            let allDefined = pointerData.byte()
            let definedBits: [UInt8]
            if allDefined == 0 {
                let bitReader = BitReader(data: pointerData.data, bitOrder: .straight)
                bitReader.index = pointerData.index
                definedBits = bitReader.bits(count: numPackStreams)
                bitReader.skipUntilNextByte()
                pointerData.index = bitReader.index
            } else {
                definedBits = Array(repeating: 1, count: numPackStreams)
            }
            for bit in definedBits {
                if bit == 1 {
                    digests.append(pointerData.uint32())
                } else {
                    digests.append(nil)
                }
            }
            type = pointerData.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

}
