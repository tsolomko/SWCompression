// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides decompression function for LZMA algorithm.
public class LZMA: DecompressionAlgorithm {

    /**
     Decompresses `data` using LZMA algortihm.

     If `data` is not actually compressed with LZMA, `LZMAError` will be thrown.

     - Parameter data: Data compressed with LZMA.

     - Throws: `LZMAError` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with LZMA at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        return Data(bytes: try decompress(pointerData))
    }

    static func decompress(_ pointerData: DataWithPointer) throws -> [UInt8] {
        let decoder = try LZMATempDecoder(pointerData)

        try decoder.setProperties(from: pointerData.byte())
        decoder.resetStateAndDecoders()
        decoder.dictionarySize = pointerData.uint32().toInt()

        let uncompressedSize = pointerData.uint64()
        if uncompressedSize == UInt64.max {
            decoder.uncompressedSize = -1
        } else {
            decoder.uncompressedSize = Int(truncatingIfNeeded: uncompressedSize)
        }

        try decoder.decode()
        return decoder.out
    }

}
