// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class SevenZipContainer: Container {

    static let signatureHeaderSize = 32

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
        let headerEndIndex: Int

        let type = pointerData.byte()
        let header: SevenZipHeader

        if type == 0x17 {
            let packedHeaderStreamInfo = try SevenZipStreamInfo(pointerData)
            headerEndIndex = pointerData.index
            header = try SevenZipHeader(pointerData, using: packedHeaderStreamInfo)
        } else if type == 0x01 {
            header = try SevenZipHeader(pointerData)
            headerEndIndex = pointerData.index
        } else {
            throw SevenZipError.wrongPropertyID
        }

        // Check header size
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
