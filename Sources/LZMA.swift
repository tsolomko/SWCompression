//
//  LZMA.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during LZMA decompression.
 It may indicate that either the data is damaged or it might not be compressed with LZMA at all.

 - `WrongProperties`: unsupported LZMA properties (greater than 225).
 */
public enum LZMAError: Error {
    /// Properties byte was greater than 225.
    case WrongProperties
}

/// Provides function to decompress data, which were compressed with LZMA
public final class LZMA: DecompressionAlgorithm {

    /**
     Decompresses `compressedData` with LZMA algortihm.

     If data passed is not actually compressed with LZMA, `LZMAError` will be thrown.

     - Parameter compressedData: Data compressed with LZMA.

     - Throws: `LZMAError` if unexpected byte (bit) sequence was encountered in `compressedData`.
     It may indicate that either the data is damaged or it might not be compressed with LZMA at all.

     - Returns: Decompressed data.
     */
    public static func decompress(compressedData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        return try decompress(pointerData: pointerData)
    }

    static func decompress(pointerData: DataWithPointer) throws -> Data {
        /// Object for storing output data
        var out: [UInt8] = []

        // First byte contains lzma properties.
        var properties = pointerData.alignedByte()
        if properties >= (9 * 5 * 5) {
            throw LZMAError.WrongProperties
        }
        /// The number of literal context bits
        let lc = properties % 9
        properties /= 9
        /// The number of pos bits
        let pb = properties / 5
        /// The number of literal pos bits
        let lp = properties % 5
        var dictionarySizeInProperties = 0
        for i in 0..<4 {
            dictionarySizeInProperties |= pointerData.alignedByte().toInt() << (8 * i)
        }
        let dictionarySize = dictionarySizeInProperties < (1 << 12) ? 1 << 12 : dictionarySizeInProperties

        print("lc: \(lc), lp: \(lp), pb: \(pb), dictionarySize: \(dictionarySize)")

        return Data(bytes: out)
    }
    
}
