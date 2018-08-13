// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides decompression function for LZMA algorithm.
public class LZMA: DecompressionAlgorithm {

    /**
     Decompresses `data` using LZMA algortihm.

     - Parameter data: Data compressed with LZMA.

     - Throws: `LZMAError` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with LZMA at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        let byteReader = ByteReader(data: data)
        return try decompress(byteReader)
    }

    static func decompress(_ byteReader: ByteReader, _ uncompSize: UInt64? = nil) throws -> Data {
        let decoder = LZMADecoder(byteReader)

        try decoder.setProperties(byteReader.byte())
        decoder.dictSize = byteReader.int(fromBytes: 4)

        let uncompSize = uncompSize ?? byteReader.uint64()
        decoder.uncompressedSize = uncompSize.toInt()

        try decoder.decode()
        return Data(bytes: decoder.out)
    }

}
