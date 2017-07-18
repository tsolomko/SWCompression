// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

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

        _ = try SevenZipHeader(pointerData)

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
