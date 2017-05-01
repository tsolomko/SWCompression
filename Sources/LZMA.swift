//
//  LZMA.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during LZMA decompression.
 It may indicate that either the data is damaged or it might not be compressed with LZMA at all.

 - `WrongProperties`: unsupported LZMA properties (greater than 225).
 - `RangeDecoderInitError`: unable to initialize RangedDecoder.
 - `ExceededUncompressedSize`: the number of uncompressed bytes reached amount specified by archive
    while decoding wasn't finished.
 - `WindowIsEmpty`: unable to repeat bytes because there is nothing to repeat.
 - `RangeDecoderFinishError`: range decoder was in a bad state when finish marker was reached.
 - `RepeatWillExceed`: unable to repeat bytes because the number of bytes to repeat is greater 
    than the amount bytes that is left to decode.
 - `NotEnoughToRepeat`: unable to repeat bytes because the amount of already decoded bytes is smaller
    than the repeat length.
 */
public enum LZMAError: Error {
    /// Properties byte was greater than 225.
    case WrongProperties
    /// Unable to initialize RanderDecorer.
    case RangeDecoderInitError
    /// The number of uncompressed bytes hit limit in the middle of decoding.
    case ExceededUncompressedSize
    /// Unable to perfrom repeat-distance decoding because there is nothing to repeat.
    case WindowIsEmpty
    /// End of stream marker is reached, but range decoder is in incorrect state.
    case RangeDecoderFinishError
    /// The number of bytes to repeat is greater than the amount bytes that is left to decode.
    case RepeatWillExceed
    /// The amount of already decoded bytes is smaller than repeat length.
    case NotEnoughToRepeat
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
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        return Data(bytes: try decompress(&pointerData))
    }

    static func decompress(_ pointerData: inout DataWithPointer) throws -> [UInt8] {
        // Firstly, we need to parse LZMA properties.
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
        var dictionarySize = pointerData.intFromAlignedBytes(count: 4)
        dictionarySize = dictionarySize < (1 << 12) ? 1 << 12 : dictionarySize

        /// Size of uncompressed data. -1 means it is unknown/undefined.
        var uncompressedSize = pointerData.intFromAlignedBytes(count: 8)
        uncompressedSize = Double(uncompressedSize) == pow(Double(2), Double(64)) - 1 ? -1 : uncompressedSize

        let lzmaDecoder = try LZMATestDecoder(&pointerData, lc, pb, lp, dictionarySize)

        return try lzmaDecoder.decodeLZMA(&uncompressedSize)
    }

}
