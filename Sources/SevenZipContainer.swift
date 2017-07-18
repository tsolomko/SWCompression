// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

fileprivate struct ArchiveProperty {
    let type: UInt8
    let size: Int
    let bytes: [UInt8]
}

public class SevenZipContainer: Container {

    public static func open(container data: Data) throws -> [ContainerEntry] {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        // **SignatureHeader**

        // Check signature.
        guard pointerData.bytes(count: 6) == [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
            else { throw SevenZipError.wrongSignature }

        // Check archive version.
        guard pointerData.bytes(count: 2) == [0, 4] // 7zFormat.txt says it should be [0, 2] instead.
            else { throw SevenZipError.wrongVersion }

        let startHeaderCRC = pointerData.uint32()

        /// - Note: Relative to SignatureHeader
        let nextHeaderOffset = Int(pointerData.uint64())
        let nextHeaderSize = Int(pointerData.uint64())
        let nextHeaderCRC = pointerData.uint32()

        pointerData.index = 12
        guard CheckSums.crc32(pointerData.bytes(count: 20)) == startHeaderCRC
            else { throw SevenZipError.wrongStartHeaderCRC }

        // **Header**
        pointerData.index += nextHeaderOffset
        let headerStartIndex = pointerData.index

        _ = try Header(pointerData)

        // TODO: It is possible, to have here HeaderInfo instead

        // Check header size
        let headerEndIndex = pointerData.index
        guard headerEndIndex - headerStartIndex == nextHeaderSize
            else { throw SevenZipError.wrongHeaderSize }

        // Check header CRC
        pointerData.index = headerStartIndex
        guard CheckSums.crc32(pointerData.bytes(count: nextHeaderSize)) == nextHeaderCRC
            else { throw SevenZipError.wrongHeaderCRC }


        return []
    }

}

fileprivate struct Header {

    var archiveProperties: [ArchiveProperty]?
    var additionalStreams: [StreamInfo]?
    var mainStreams: [StreamInfo]?
    var files: [FileInfo]?

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
                archiveProperties = try Header.getArchiveProperties(pointerData)
            case 0x03: // **Header - AdditionalStreamsInfo**
                _ = try StreamInfo(pointerData) // TODO: Or it can be more than one?
            case 0x04: // **Header - MainStreamsInfo**
                _ = try StreamInfo(pointerData)
            case 0x05: // **Header - FilesInfo**
                break
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
            let propertySize = try pointerData.multiByteDecode().multiByteInteger
            archiveProperties.append(ArchiveProperty(type: type, size: propertySize,
                                                     bytes: pointerData.bytes(count: propertySize)))
        }
        return archiveProperties
    }

}

fileprivate struct StreamInfo {

    var pack: PackInfo?
    var coders: [CoderInfo]?
    var substreams: [SubstreamInfo]?

    init(_ pointerData: DataWithPointer) throws  {
        while true {
            let structureType = pointerData.byte()
            if structureType == 0x00 { // **StreamsInfo - End**
                break
            }
            switch structureType {
            case 0x06: // **StreamsInfo - PackInfo**
                break
            case 0x07: // **StreamsInfo - CodersInfo**
                break
            case 0x08: // **StreamsInfo - SubstreamsInfo**
                break
            default:
                throw SevenZipError.wrongPropertyID
            }
        }
    }

}

fileprivate struct FileInfo {

}

fileprivate struct PackInfo {

}

fileprivate struct CoderInfo {

}

fileprivate struct SubstreamInfo {

}

fileprivate extension DataWithPointer {

    fileprivate func multiByteDecode() throws -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        var i = 1
        var result = self.byte().toInt()
        var bytes: [UInt8] = [result.toUInt8()]
        if result <= 127 {
            return (result, bytes)
        }
        result &= 0x7F
        while self.previousByte & 0x80 != 0 {
            let byte = self.byte()
            if i >= 9 || byte == 0x00 {
                throw SevenZipError.multiByteIntegerError
            }
            bytes.append(byte)
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return (result, bytes)
    }
    
}
