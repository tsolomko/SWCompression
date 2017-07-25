// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipStreamInfo {

    var packInfo: SevenZipPackInfo?
    var coderInfo: SevenZipCoderInfo
    var substreamInfo: SevenZipSubstreamInfo?

    init(_ pointerData: DataWithPointer) throws {
        var type = pointerData.byte()

        if type == 0x06 {
            packInfo = try SevenZipPackInfo(pointerData)
            type = pointerData.byte()
        }

        if type == 0x07 {
            coderInfo = try SevenZipCoderInfo(pointerData)
            type = pointerData.byte()
        } else {
            coderInfo = SevenZipCoderInfo()
        }

        if type == 0x08 {
            substreamInfo = try SevenZipSubstreamInfo(pointerData, coderInfo)
            type = pointerData.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

}
