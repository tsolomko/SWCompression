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

        let dictionarySize = try LZMA2.dictionarySize(pointerData.byte())

        return Data(bytes: try LZMA2.decompress(dictionarySize, pointerData))
    }

    static func decompress(_ dictionarySize: Int, _ pointerData: DataWithPointer) throws -> [UInt8] {
        // At this point lzmaDecoder will be in a VERY bad state.
        let lzmaDecoder = try LZMADecoder(pointerData)
        try lzmaDecoder.decodeLZMA2(dictionarySize)
        return lzmaDecoder.out
    }

    static func dictionarySize(_ byte: UInt8) throws -> Int {
        let bits = byte & 0x3F
        guard byte & 0xC0 == 0
            else { throw LZMA2Error.wrongProperties }
        guard bits < 40
            else { throw LZMA2Error.wrongDictionarySize }

        var dictSize: UInt32 = 0
        if bits == 40 {
            dictSize = UInt32.max
        } else {
            dictSize = UInt32(2 | (bits.toInt() & 1))
            dictSize <<= UInt32(bits.toInt() / 2 + 11)
        }
        return Int(dictSize)
    }

}
