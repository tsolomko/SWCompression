// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

public enum LZ4: DecompressionAlgorithm {

    public static func decompress(data: Data) throws -> Data {
        let reader = LittleEndianByteReader(data: data)
        // TODO: Switch between frame and block decoding modes?
        // TODO: Small/empty data size check.
        guard reader.uint32() == 0x184D2204
            else { throw DataError.corrupted }
        fatalError("Not implemented yet")
    }

}
