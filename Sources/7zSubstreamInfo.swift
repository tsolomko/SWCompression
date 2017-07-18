// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipSubstreamInfo {

    var numUnpackStreamsInFolders: [Int]?
    var unpackSizes: [Int]?

    init(_ pointerData: DataWithPointer, _ numFolders: Int) throws {
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **SubstreamsInfo - End**
                break
            }
            switch structureType {
            case 0x0D: // **SubstreamsInfo - NumUnpackStreamsInFolders**
                numUnpackStreamsInFolders = []
                for _ in 0..<numFolders {
                    numUnpackStreamsInFolders?
                        .append(try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger)
                }
            case 0x09: // **SubstreamsInfo - Size**
                // TODO: How many sizes?
                //
                //    []
                //    BYTE NID::kSize  (0x09)
                //    UINT64 UnPackSizes[]
                //    []
                //
                break
            case 0x0A: // **SubstreamsInfo - CRC**
                // TODO:
                //
                //    []
                //    BYTE NID::kCRC  (0x0A)
                //    Digests[Number of streams with unknown CRC]
                //    []
                //
                break
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }

}
