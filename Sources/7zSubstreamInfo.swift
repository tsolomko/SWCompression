// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipSubstreamInfo {

    var numUnpackStreamsInFolders = [Int]()
    var unpackSizes = [Int]()
    var digests = [UInt32?]()

    init(_ pointerData: DataWithPointer, _ numFolders: Int) throws {
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **SubstreamsInfo - End**
                break
            }
            switch structureType {
            case 0x0D: // **SubstreamsInfo - NumUnpackStreamsInFolders**
                for _ in 0..<numFolders {
                    numUnpackStreamsInFolders
                        .append(try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger)
                }
            case 0x09: // **SubstreamsInfo - Size**
                let numStreams = numUnpackStreamsInFolders.reduce(0, { $0 + $1 })
                for _ in 0..<numStreams {
                    unpackSizes.append(try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger)
                }
            case 0x0A: // **SubstreamsInfo - CRC** // TODO: Unknown numStreams???
                let allDefined = pointerData.byte()
                let definedBits: [UInt8]
                let numStreams = numUnpackStreamsInFolders.reduce(0, { $0 + $1 })
                if allDefined == 0 {
                    let bitReader = BitReader(data: pointerData.data, bitOrder: .reversed) // TODO: Bit order???
                    bitReader.index = pointerData.index
                    definedBits = bitReader.bits(count: numStreams)
                    bitReader.skipUntilNextByte()
                    pointerData.index = bitReader.index
                } else {
                    definedBits = Array(repeating: 1, count: numStreams)
                }
                for bit in definedBits {
                    if bit == 1 {
                        digests.append(pointerData.uint32())
                    } else {
                        digests.append(nil)
                    }
                }
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }

}
