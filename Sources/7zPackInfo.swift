// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipPackInfo {

    let packPosition: Int
    let numPackStreams: Int

    var sizes: [Int]?

    init(_ pointerData: DataWithPointer) throws {
        packPosition = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
        numPackStreams = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **PackInfo - End**
                break
            }
            switch structureType {
            case 0x09: // **PackInfo - PackSizes**
                sizes = []
                for _ in 0..<numPackStreams {
                    sizes?.append(try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger)
                }
            case 0x0A: // **PackInfo - PackStreamDigests**
                // TODO:
                //    []
                //    BYTE NID::kCRC      (0x0A)
                //    PackStreamDigests[NumPackStreams]
                //    []
                break
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }
    
}
