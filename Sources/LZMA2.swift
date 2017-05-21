//
//  LZMA2.swift
//  SWCompression
//
//  Created by Timofey Solomko on 22.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during LZMA2 decompression.
 It may indicate that either the data is damaged or it might not be compressed with LZMA2 at all.

 - `wrongProperties`: reserved bits of LZMA2 properties byte weren't zero.
 - `wrongDictionarySize`: dictionary size was greater than 2^32.
 - `wrongControlByte`: unsupported value of LZMA2 packet's control byte.
 - `wrongReset`: unsupported 'reset' value of LZMA2 packet's.
 - `wrongSizes`: size of compressed or decompressed data wasn't the same as specified in LZMA2 packet.
 */
public enum LZMA2Error: Error {
    /// Reserved bits of LZMA2 properties byte were not equal to zero.
    case wrongProperties
    /// Dictionary size was too big.
    case wrongDictionarySize
    /// Unknown conrol byte value of LZMA2 packet.
    case wrongControlByte
    /// Unknown reset instruction encounetered in LZMA2 packet.
    case wrongReset
    /**
     Either size of decompressed data was not equal to specified one in LZMA2 packet or
     amount of compressed data read was different from the one stored in LZMA2 packet.
     */
    case wrongSizes
}

/// Provides function to decompress data, which were compressed with LZMA2
public final class LZMA2: DecompressionAlgorithm {

    /**
     Decompresses `compressedData` with LZMA2 algortihm. LZMA2 is a modification of LZMA.

     If data passed is not actually compressed with LZMA2, `LZMA2Error` or `LZMAError` will be thrown.

     - Parameter compressedData: Data compressed with LZMA2.

     - Throws: `LZMA2Error` or `LZMAError` if unexpected byte (bit) sequence was encountered in `compressedData`.
     It may indicate that either the data is damaged or it might not be compressed with LZMA2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(compressedData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        let dictionarySize = try LZMA2.dictionarySize(pointerData.alignedByte())

        return Data(bytes: try LZMA2.decompress(dictionarySize, &pointerData))
    }

    static func decompress(_ dictionarySize: Int, _ pointerData: inout DataWithPointer) throws -> [UInt8] {
        // At this point lzmaDecoder will be in a VERY bad state.
        let lzmaDecoder = try LZMADecoder(&pointerData, 0, 0, 0, 0)
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
