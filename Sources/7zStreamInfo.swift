// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipStreamInfo {

    var pack: SevenZipPackInfo?
    var coders: SevenZipCoderInfo?
    var substreams: [SevenZipSubstreamInfo]?

    init(_ pointerData: DataWithPointer) throws  {
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **StreamsInfo - End**
                break
            }
            switch structureType {
            case 0x06: // **StreamsInfo - PackInfo**
                pack = try SevenZipPackInfo(pointerData)
            case 0x07: // **StreamsInfo - CodersInfo**
                coders = try SevenZipCoderInfo(pointerData)
            case 0x08: // **StreamsInfo - SubstreamsInfo**
                break
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }
    
}
