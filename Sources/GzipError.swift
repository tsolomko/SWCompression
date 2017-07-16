// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during processing GZip archive.
 It may indicate that either archive is damaged or it might not be GZip archive at all.
 */
public enum GzipError: Error {
    /// First two bytes ('magic' number) of archive isn't 31 and 139.
    case wrongMagic
    /// Compression method used in archive is different from Deflate, which is the only supported one.
    case wrongCompressionMethod
    /**
     One of the reserved fields in archive has an unexpected value, which can also mean (apart from damaged archive),
     that archive uses a newer version of GZip format.
     */
    case wrongFlags
    /// Computed CRC of archive's header doesn't match the value stored in archive.
    case wrongHeaderCRC
    /**
     Computed checksum of uncompressed data doesn't match the value stored in archive.
     Associated value of the error contains already decompressed data.
     */
    case wrongCRC(Data)
    /// Computed 'isize' didn't match the value stored in the archive.
    case wrongISize
    /// Either specified file name or comment cannot be encoded using ISO Latin-1 encoding.
    case cannotEncodeISOLatin1
}
