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

    init(_ bitReader: BitReader) throws {
        var type = bitReader.byte()

        if type == 0x02 {
            archiveProperties = try SevenZipProperty.getProperties(bitReader)
            type = bitReader.byte()
        }

        if type == 0x03 {
            // TODO: Do we support this?
            // TODO: Or it can be more than one?
            throw SevenZipError.additionalStreamsNotSupported
//            additionalStreams = try SevenZipStreamInfo(bitReader)
//            type = bitReader.byte()
        }

        if type == 0x04 {
            mainStreams = try SevenZipStreamInfo(bitReader)
            type = bitReader.byte()
        }

        if type == 0x05 {
            fileInfo = try SevenZipFileInfo(bitReader)
            type = bitReader.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

    convenience init(_ bitReader: BitReader, using streamInfo: SevenZipStreamInfo) throws {
        let folder = streamInfo.coderInfo.folders[0]
        guard let packInfo = streamInfo.packInfo
            else { throw SevenZipError.noPackInfo }

        let folderOffset = SevenZipContainer.signatureHeaderSize + packInfo.packPosition
        bitReader.index = folderOffset

        let packedHeaderData = Data(bitReader.bytes(count: packInfo.packSizes[0]))
        let headerData = try folder.unpack(data: packedHeaderData)

        guard headerData.count == folder.unpackSize()
            else { throw SevenZipError.wrongDataSize }
        if let crc = folder.crc {
            guard CheckSums.crc32(headerData) == crc
                else { throw SevenZipError.wrongCRC }
        }

        let headerBitReader = BitReader(data: headerData, bitOrder: .straight)

        guard headerBitReader.byte() == 0x01
            else { throw SevenZipError.wrongPropertyID }
        try self.init(headerBitReader)
    }

}
