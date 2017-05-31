//
//  LZMA.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Represents an error, which happened during LZMA decompression.
 It may indicate that either data is damaged or it might not be compressed with LZMA at all.
 */
public enum LZMAError: Error {
    /// Properties' byte is greater than 225.
    case wrongProperties
    /// Unable to initialize RanderDecorer.
    case rangeDecoderInitError
    /// Size of uncompressed data hit specified limit in the middle of decoding.
    case exceededUncompressedSize
    /// Unable to perfrom repeat-distance decoding because there is nothing to repeat.
    case windowIsEmpty
    /// End of stream marker is reached, but range decoder is in incorrect state.
    case rangeDecoderFinishError
    /// The number of bytes to repeat is greater than the amount bytes that is left to decode.
    case repeatWillExceed
    /// The amount of already decoded bytes is smaller than repeat length.
    case notEnoughToRepeat
    /// LZMADecoder wasn't properly initialized before decoding data.
    case decoderIsNotInitialised
}

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
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        return Data(bytes: try decompress(&pointerData))
    }

    static func decompress(_ pointerData: inout DataWithPointer) throws -> [UInt8] {
        let lzmaDecoder = try LZMADecoder(&pointerData)
        try lzmaDecoder.decodeLZMA()
        return lzmaDecoder.out
    }

}
