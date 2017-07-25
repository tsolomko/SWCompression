// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipProperty {

    let type: UInt8
    let size: Int
    let bytes: [UInt8]

    static func getProperties(_ pointerData: DataWithPointer) throws -> [SevenZipProperty] {
        var properties = [SevenZipProperty]()
        while true {
            let propertyType = pointerData.byte()
            if propertyType == 0 {
                break
            }
            let propertySize = pointerData.szMbd().multiByteInteger
            properties.append(SevenZipProperty(type: propertyType, size: propertySize,
                                               bytes: pointerData.bytes(count: propertySize)))
        }
        return properties
    }

}

struct SevenZipHeader {

    var archiveProperties: [SevenZipProperty]?
    var additionalStreams: SevenZipStreamInfo?
    var mainStreams: SevenZipStreamInfo?
    var fileInfo: SevenZipFileInfo?

    init(_ pointerData: DataWithPointer) throws {
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **Header - End**
                break
            }
            switch structureType {
            case 0x02: // **Header - ArchiveProperties**
                archiveProperties = try SevenZipProperty.getProperties(pointerData)
            case 0x03: // **Header - AdditionalStreamsInfo**
                additionalStreams = try SevenZipStreamInfo(pointerData) // TODO: Or it can be more than one?
            case 0x04: // **Header - MainStreamsInfo**
                mainStreams = try SevenZipStreamInfo(pointerData)
            case 0x05: // **Header - FilesInfo**
                fileInfo = try SevenZipFileInfo(pointerData)
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }

    // TODO: Remove this function.

    
}
