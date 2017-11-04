// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct XZBlock {

    let data: Data
    let unpaddedSize: Int

    var uncompressedSize: Int {
        return data.count
    }

    init(_ blockHeaderSize: UInt8, _ pointerData: DataWithPointer, _ checkSize: Int) throws {
        let blockHeaderStartIndex = pointerData.index - 1
        let realBlockHeaderSize = (blockHeaderSize.toInt() + 1) * 4

        let blockFlags = pointerData.byte()
        /**
         Bit values 00, 01, 10, 11 indicate filters number from 1 to 4,
         so we actually need to add 1 to get filters' number.
         */
        let filtersCount = blockFlags & 0x03 + 1
        guard blockFlags & 0x3C == 0
            else { throw XZError.wrongFieldValue }

        /// Should match size of compressed data.
        let compressedSize = blockFlags & 0x40 != 0 ? try pointerData.multiByteDecode() : -1

        /// Should match the size of data after decompression.
        let uncompressedSize = blockFlags & 0x80 != 0 ? try pointerData.multiByteDecode() : -1

        var filters: [(DataWithPointer) throws -> Data] = []
        for _ in 0..<filtersCount {
            let filterID = try pointerData.multiByteDecode()
            guard UInt64(filterID) < 0x4000000000000000
                else { throw XZError.wrongFilterID }
            // Only LZMA2 filter is supported.
            if filterID == 0x21 {
                // First, we need to skip byte with the size of filter's properties
                _ = try pointerData.multiByteDecode()
                /// In case of LZMA2 filters property is a dicitonary size.
                let filterPropeties = pointerData.byte()
                let closure = { (dwp: DataWithPointer) -> Data in
                    let decoder = try LZMA2Decoder(pointerData)
                    try decoder.setDictionarySize(filterPropeties)

                    try decoder.decode()
                    return Data(bytes: decoder.out)
                }
                filters.append(closure)
            } else {
                throw XZError.wrongFilterID
            }
        }

        // We need to take into account 4 bytes for CRC32 so thats why "-4".
        while pointerData.index - blockHeaderStartIndex < realBlockHeaderSize - 4 {
            let byte = pointerData.byte()
            guard byte == 0x00
                else { throw XZError.wrongPadding }
        }

        let blockHeaderCRC = pointerData.uint32()
        pointerData.index = blockHeaderStartIndex
        guard CheckSums.crc32(pointerData.bytes(count: realBlockHeaderSize - 4)) == blockHeaderCRC
            else { throw XZError.wrongInfoCRC }
        pointerData.index += 4

        var intResult = pointerData
        let compressedDataStart = pointerData.index
        for filterIndex in 0..<filtersCount - 1 {
            let intData = try filters[filtersCount.toInt() - filterIndex.toInt() - 1](intResult)
            intResult = DataWithPointer(data: intData)
        }
        guard compressedSize < 0 || compressedSize == pointerData.index - compressedDataStart
            else { throw XZError.wrongDataSize }

        let out = try filters[filtersCount.toInt() - 1](intResult)
        guard uncompressedSize < 0 || uncompressedSize == out.count
            else { throw XZError.wrongDataSize }

        let unpaddedSize = pointerData.index - blockHeaderStartIndex

        if unpaddedSize % 4 != 0 {
            let paddingSize = 4 - unpaddedSize % 4
            for _ in 0..<paddingSize {
                let byte = pointerData.byte()
                guard byte == 0x00
                    else { throw XZError.wrongPadding }
            }
        }

        self.data = out
        self.unpaddedSize = unpaddedSize + checkSize
    }

}
