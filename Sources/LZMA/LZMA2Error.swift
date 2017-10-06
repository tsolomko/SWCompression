// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during LZMA2 decompression.
 It may indicate that either data is damaged or it might not be compressed with LZMA2 at all.
 */
public enum LZMA2Error: Error {
    /// Reserved bits of LZMA2 properties' byte aren't equal to zero.
    case wrongProperties
    /// Dictionary size is too big.
    case wrongDictionarySize
    /// Unknown conrol byte value of LZMA2 packet.
    case wrongControlByte
    /// Unknown reset instruction encountered in LZMA2 packet.
    case wrongReset
    /**
     Either size of decompressed data isn't equal to the one specified in LZMA2 packet or
     amount of compressed data read is different from the one stored in LZMA2 packet.
     */
    case wrongSizes
}
