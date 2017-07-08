//
//  LZMA.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

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
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        return Data(bytes: try decompress(&pointerData))
    }

    /**
     - Parameter externalUncompressedSize: stream doesn't contain uncompressed size property,
     and decoder should use externally specified uncompressed size.
     Used in ZIP containers with LZMA compression.
     */
    static func decompress(_ pointerData: inout DataWithPointer, _ externalUncompressedSize: Int? = nil) throws -> [UInt8] {
        let lzmaDecoder = try LZMADecoder(&pointerData)
        try lzmaDecoder.decodeLZMA(externalUncompressedSize)
        return lzmaDecoder.out
    }

}
