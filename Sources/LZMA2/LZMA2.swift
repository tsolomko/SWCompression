// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides decompression function for LZMA2 algorithm.
public class LZMA2: DecompressionAlgorithm {

    /**
     Decompresses `data` using LZMA2 algortihm.

     If `data` is not actually compressed with LZMA2, `LZMAError` or `LZMA2Error` will be thrown.

     - Parameter data: Data compressed with LZMA2.

     - Throws: `LZMAError` or `LZMA2Error` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with LZMA2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        return Data(bytes: try decompress(pointerData))
    }

    static func decompress(_ pointerData: DataWithPointer) throws -> [UInt8] {
        let decoder = LZMA2Decoder(pointerData)
        try decoder.setDictionarySize(pointerData.byte())
        try decoder.decode()
        return decoder.out
    }

}
