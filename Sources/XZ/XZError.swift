// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during unarchiving XZ archive.
 It may indicate that either archive is damaged or it might not be XZ archive at all.
 */
public enum XZError: Error {
    /// Either 'magic' number in header or footer isn't equal to a predefined value.
    case wrongMagic
    /**
     One of the special fields in archive has an incorrect value,
     which can mean both damaged archive or that archive uses a newer version of XZ format.
     */
    case wrongFieldValue
    /// Checksum of one of the fields of archive doesn't match the value stored in archive.
    case wrongInfoCRC
    /// Filter used in archvie is unsupported.
    case wrongFilterID
    /// Archive uses SHA-256 checksum which is unsupported.
    case checkTypeSHA256
    /**
     Either size of decompressed data isn't equal to the one specified in archive or
     amount of compressed data read is different from the one stored in archive.
     */
    case wrongDataSize
    /**
     Computed checksum of uncompressed data doesn't match the value stored in the archive.
     Associated value of the error contains already decompressed data.
     */
    case wrongCheck(Data)
    /// Padding (null-bytes appended to an archive's structure) is incorrect.
    case wrongPadding
    /// Either null byte encountered or exceeded maximum amount bytes during reading multi byte number.
    case multiByteIntegerError
}
