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

 - `wrongProperties`: unsupported LZMA properties (greater than 225).
 - `rangeDecoderInitError`: unable to initialize RangedDecoder.
 - `exceededUncompressedSize`: the number of uncompressed bytes reached amount specified by archive
    while decoding wasn't finished.
 - `windowIsEmpty`: unable to repeat bytes because there is nothing to repeat.
 - `rangeDecoderFinishError`: range decoder was in a bad state when finish marker was reached.
 - `repeatWillExceed`: unable to repeat bytes because the number of bytes to repeat is greater
    than the amount bytes that is left to decode.
 - `notEnoughToRepeat`: unable to repeat bytes because the amount of already decoded bytes is smaller
    than the repeat length.
 */
public enum LZMAError: Error {
    /// Properties byte was greater than 225.
    case wrongProperties
    /// Unable to initialize RanderDecorer.
    case rangeDecoderInitError
    /// The number of uncompressed bytes hit limit in the middle of decoding.
    case exceededUncompressedSize
    /// Unable to perfrom repeat-distance decoding because there is nothing to repeat.
    case windowIsEmpty
    /// End of stream marker is reached, but range decoder is in incorrect state.
    case rangeDecoderFinishError
    /// The number of bytes to repeat is greater than the amount bytes that is left to decode.
    case repeatWillExceed
    /// The amount of already decoded bytes is smaller than repeat length.
    case notEnoughToRepeat

    case decoderIsNotInitialised
}

/// Provides function to decompress data, which were compressed with LZMA
public class LZMA: DecompressionAlgorithm {

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
        let lzmaDecoder = try LZMADecoder(&pointerData)
        try lzmaDecoder.decodeLZMA()
        return lzmaDecoder.out
    }

}
