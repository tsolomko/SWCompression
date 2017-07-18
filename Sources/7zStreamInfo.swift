// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipStreamInfo {

    var packInfo: SevenZipPackInfo?
    var coderInfo: SevenZipCoderInfo?
    var substreamInfo: SevenZipSubstreamInfo?

    init(_ pointerData: DataWithPointer) throws  {
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **StreamsInfo - End**
                break
            }
            switch structureType {
            case 0x06: // **StreamsInfo - PackInfo**
                packInfo = try SevenZipPackInfo(pointerData)
            case 0x07: // **StreamsInfo - CodersInfo**
                coderInfo = try SevenZipCoderInfo(pointerData)
            case 0x08: // **StreamsInfo - SubstreamsInfo**
                guard let numFolders = coderInfo?.numFolders
                    else { throw SevenZipError.unknownNumFolders }
                substreamInfo = try SevenZipSubstreamInfo(pointerData, numFolders)
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }
    
}
