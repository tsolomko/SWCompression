// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class SevenZipContainer: Container {

    static let signatureHeaderSize = 0

    // Coder IDs
    static let lzma2ID: [UInt8] = [0x21]
    static let lzmaID: [UInt8] = [0x03, 0x01, 0x01]

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

        var type = pointerData.byte()
        let header: SevenZipHeader

        if type == 0x17 {
            let packedHeaderStreamInfo = try SevenZipStreamInfo(pointerData)
            let folder = packedHeaderStreamInfo.coderInfo.folders[0]
            guard let packInfo = packedHeaderStreamInfo.packInfo else { return [] } // TODO: throw
            let folderOffset = signatureHeaderSize + packInfo.packPosition
            pointerData.index = folderOffset
            var packedHeaderEndIndex: Int? = nil
            var headerPointerData = DataWithPointer(data: pointerData.data)
            headerPointerData.index = pointerData.index
            for coder in folder.orderedCoders() {
                guard coder.numInStreams == 1 || coder.numOutStreams == 1
                    else { throw SevenZipError.multiStreamNotSupported }
                let decodedData: Data
                let unpackSize = folder.unpackSize(for: coder)
                if coder.id == lzma2ID {
                    precondition(coder.propertiesSize == 1) // TODO:
                    decodedData = Data(bytes: try LZMA2.decompress(LZMA2.dictionarySize(coder.properties![0]), // TODO:
                                                                   pointerData))
                } else if coder.id == lzmaID {
                    var dataToDecode = Data(bytes: coder.properties!) // TODO:
                    dataToDecode.append(headerPointerData.data.subdata(in: headerPointerData.index..<headerPointerData.size)) // TODO:
                    decodedData = Data(bytes: try LZMA.decompress(DataWithPointer(data: dataToDecode), unpackSize))
                } else {
                    throw SevenZipError.compressionNotSupported
                }
                guard decodedData.count == unpackSize
                    else { throw SevenZipError.wrongDataSize }
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
            header = try SevenZipHeader(headerPointerData)
            type = pointerData.byte()
        } else if type == 0x01 {
            header = try SevenZipHeader(pointerData)
            type = pointerData.byte()
        } else {
            throw SevenZipError.wrongPropertyID
        }
        print(header)

        // TODO: Header checks may be incorrect for packed headers.
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

extension DataWithPointer {

    // TODO: Do we need bytesProcessed?
    /// Abbreviation for "sevenZipMultiByteDecode".
    func szMbd() -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        let firstByte = self.byte().toInt()
        var mask = 0x80
        var bytes = [firstByte.toUInt8()]
        var value = 0
        for i in 0..<8 {
            if firstByte & mask == 0 {
                value |= ((firstByte & (mask &- 1)) << (8 * i))
                break
            }
            let nextByte = self.byte().toInt()
            bytes.append(nextByte.toUInt8())
            value |= nextByte << (8 * i)
            mask >>= 1
        }
        return (value, bytes)
    }

}
