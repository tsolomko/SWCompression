//
//  BZip2.swift
//  SWCompression
//
//  Created by Timofey Solomko on 12.11.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

/**
 Error happened during bzip2 decompression.
 It may indicate that either the data is damaged or it might not be compressed with BZip2 at all.

 - `WrongCompressionMethod`: unsupported compression method (not type 'h').
 - `WrongBlockSize`: unsupported block size (not '0' — '9').
 - `WrongBlockType`: unsupported block type (not 'pi' or 'sqrt(pi)').
 */
public enum BZip2Error: Error {
    /// Compression method was not type 'h' (not Huffman).
    case WrongCompressionMethod
    /// Unknown block size (not from '0' to '9').
    case WrongBlockSize
    /// Unknown block type (was neither 'pi' nor 'sqrt(pi)').
    case WrongBlockType
}

/// Provides function to decompress data, which were compressed using BZip2
public class BZip2: DecompressionAlgorithm {

    /**
     Decompresses `compressedData` with BZip2 algortihm.

     If data passed is not actually compressed with BZip2, `BZip2Error` will be thrown.

     - Parameter compressedData: Data compressed with BZip2.

     - Throws: `BZip2Error` if unexpected byte (bit) sequence was encountered in `compressedData`.
     It may indicate that either the data is damaged or it might not be compressed with BZip2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(compressedData data: Data) throws -> Data {
        /// Object for storing output data
        var out = Data()

        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        let method = convertToInt(uint8Array: pointerData.bits(count: 8))
        guard method == 104 else { throw BZip2Error.WrongCompressionMethod }

        var blockSize = convertToInt(uint8Array: pointerData.bits(count: 8))
        if blockSize >= 49 && blockSize <= 57 {
            blockSize -= 48
        } else {
            throw BZip2Error.WrongBlockSize
        }

        while true {
            let blockType = convertToInt(uint8Array: pointerData.bits(count: 48))
            let crc = convertToInt(uint8Array: pointerData.bits(count: 32))

            if blockType == 0x314159265359 {
                try out.append(decodeHuffmanBlock(data: pointerData))
            } else if blockType == 0x177245385090 {
                pointerData.skipUntilNextByte()
            } else {
                throw BZip2Error.WrongBlockType
            }
        }
        
        return out
    }

    private func decodeHuffmanBlock(data: DataWithPointer) throws -> Data {
        return Data()
    }

}
