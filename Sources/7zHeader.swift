// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipHeader {

    struct ArchiveProperty {

        let type: UInt8
        let size: Int
        let bytes: [UInt8]
        
    }

    var archiveProperties: [ArchiveProperty]?
    var additionalStreams: SevenZipStreamInfo?
    var mainStreams: SevenZipStreamInfo?
    var fileInfo: SevenZipFileInfo?

    init(_ pointerData: DataWithPointer) throws {
        guard pointerData.byte() == 0x01
            else { throw SevenZipError.wrongPropertyID }

        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **Header - End**
                break
            }
            switch structureType {
            case 0x02: // **Header - ArchiveProperties**
                archiveProperties = try SevenZipHeader.getArchiveProperties(pointerData)
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

    private static func getArchiveProperties(_ pointerData: DataWithPointer) throws -> [ArchiveProperty] {
        var archiveProperties = [ArchiveProperty]()
        while true {
            let type = pointerData.byte()
            if type == 0 {
                break
            }
            let propertySize = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
            archiveProperties.append(ArchiveProperty(type: type, size: propertySize,
                                                     bytes: pointerData.bytes(count: propertySize)))
        }
        return archiveProperties
    }
    
}
