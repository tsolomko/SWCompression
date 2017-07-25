// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipPackInfo {

    let packPosition: Int
    let numPackStreams: Int
    var packSizes = [Int]()
    var digests = [UInt32?]()

    init(_ pointerData: DataWithPointer) throws {
        packPosition = pointerData.szMbd().multiByteInteger
        numPackStreams = pointerData.szMbd().multiByteInteger
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **PackInfo - End**
                break
            }
            switch structureType {
            case 0x09: // **PackInfo - PackSizes**
                for _ in 0..<numPackStreams {
                    packSizes.append(pointerData.szMbd().multiByteInteger)
                }
            case 0x0A: // **PackInfo - PackStreamDigests**
                let allDefined = pointerData.byte()
                let definedBits: [UInt8]
                let numStreams = numPackStreams
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
