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
            throw SevenZipError.additionalStreamsNotSupported
//            additionalStreams = try SevenZipStreamInfo(pointerData)
//            type = pointerData.byte()
        }

        if type == 0x04 {
            mainStreams = try SevenZipStreamInfo(pointerData)
            type = pointerData.byte()
        }

        if type == 0x05 {
            fileInfo = try SevenZipFileInfo(pointerData)
            type = pointerData.byte()
        }

        if let fileInfo = fileInfo {
            var nonEmptyFileIndex = 0
            for i in 0..<fileInfo.files.count {
                if !fileInfo.files[i].isEmptyStream {
                    fileInfo.files[i].crc = mainStreams?.substreamInfo?.digests[nonEmptyFileIndex]
                    guard let size = mainStreams?.substreamInfo?.unpackSizes[nonEmptyFileIndex]
                        else { throw SevenZipError.noFileSize }
                    fileInfo.files[i].size = size
                    nonEmptyFileIndex += 1
                }
            }
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

    convenience init(_ pointerData: DataWithPointer, using streamInfo: SevenZipStreamInfo) throws {
        let folder = streamInfo.coderInfo.folders[0]
        guard let packInfo = streamInfo.packInfo
            else { throw SevenZipError.noPackInfo }

        let folderOffset = SevenZipContainer.signatureHeaderSize + packInfo.packPosition
        pointerData.index = folderOffset

        var packedHeaderEndIndex: Int? = nil

        var headerPointerData = DataWithPointer(data: pointerData.data)
        headerPointerData.index = pointerData.index

        for coder in folder.orderedCoders() {
            guard coder.numInStreams == 1 || coder.numOutStreams == 1
                else { throw SevenZipError.multiStreamNotSupported }

            let unpackSize = folder.unpackSize(for: coder)

            let decodedData: Data

            if coder.id == SevenZipCoder.ID.lzma2 {
                // Dictionary size is stored in coder's properties.
                guard let properties = coder.properties
                    else { throw SevenZipError.wrongCoderProperties }
                guard properties.count == 1
                    else { throw SevenZipError.wrongCoderProperties }

                decodedData = Data(bytes: try LZMA2.decompress(LZMA2.dictionarySize(properties[0]),
                                                               pointerData))
            } else if coder.id == SevenZipCoder.ID.lzma {
                // Both properties' byte (lp, lc, pb) and dictionary size are stored in coder's properties.
                guard let properties = coder.properties
                    else { throw SevenZipError.wrongCoderProperties }
                guard properties.count == 5
                    else { throw SevenZipError.wrongCoderProperties }

                let lzmaDecoder = try LZMADecoder(headerPointerData)

                var dictionarySize = 0
                for i in 1..<4 {
                    dictionarySize |= properties[i].toInt() << (8 * (i - 1))
                }

                try lzmaDecoder.decodeLZMA(unpackSize, properties[0], dictionarySize)
                decodedData = Data(bytes: lzmaDecoder.out)
            } else {
                throw SevenZipError.compressionNotSupported
            }

            guard decodedData.count == unpackSize
                else { throw SevenZipError.wrongDataSize }

            // Save header's data end index after first pass.
            // Necessary to calculate and check packed size later.
            if packedHeaderEndIndex == nil {
                packedHeaderEndIndex = headerPointerData.index
            }

            headerPointerData = DataWithPointer(data: decodedData)
        }

        guard packedHeaderEndIndex! - pointerData.index == packInfo.packSizes[0]
            else { throw SevenZipError.wrongDataSize }
        guard headerPointerData.size == folder.unpackSize()
            else { throw SevenZipError.wrongDataSize }
        if let crc = folder.crc {
            guard CheckSums.crc32(headerPointerData.data) == crc
                else { throw SevenZipError.wrongCRC }
        }

        guard headerPointerData.byte() == 0x01
            else { throw SevenZipError.wrongPropertyID }
        try self.init(headerPointerData)
    }

}
