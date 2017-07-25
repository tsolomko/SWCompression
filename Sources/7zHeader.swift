// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipHeader {

    var archiveProperties: [SevenZipProperty]?
    var additionalStreams: SevenZipStreamInfo?
    var mainStreams: SevenZipStreamInfo?
    var fileInfo: SevenZipFileInfo?

    init(_ pointerData: DataWithPointer) throws {
        var type = pointerData.byte()

        if type == 0x02 {
            archiveProperties = try SevenZipProperty.getProperties(pointerData)
            type = pointerData.byte()
        }

        if type == 0x03 {
            // TODO: Do we support this?
            // TODO: Or it can be more than one?
            additionalStreams = try SevenZipStreamInfo(pointerData)
            type = pointerData.byte()
        }

        if type == 0x04 {
            mainStreams = try SevenZipStreamInfo(pointerData)
            type = pointerData.byte()
        }

        if type == 0x05 {
            fileInfo = try SevenZipFileInfo(pointerData)
            type = pointerData.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

}
