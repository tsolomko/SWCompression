//
//  XzArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 18.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during unarchiving xz archive.
 It may indicate that either the data is damaged or it might not be xz archive at all.

 - `WrongMagic`: first two bytes of archive were not `{ 0xFD, '7', 'z', 'X', 'Z', 0x00 }`.
 - `WrongFlagsFirstByte`: first byte of the flags was not zero.
 - `WrongCheckType`: unsupported check type (not 0x00, 0x01, 0x04 or 0x0A).
 - `WrongFlagsLastFourBits`: Last four bits of the flags were not zero.
 - `WrongFlagsCRC`: calculated crc-32 for flags doesn't equal to the value stored in the archive.
 */
public enum XZError: Error {
    /// First six bytes of archive were not equal to 0xFD377A585A00.
    case WrongMagic
    /// First byte of the flags was not equal to zero.
    case WrongFlagsFirstByte
    /// Type of check was equal to one of the reserved values.
    case WrongCheckType
    /// Last four bits of the flags were not equal to zero.
    case WrongFlagsLastFourBits
    /// Checksum for flags is incorrect.
    case WrongFlagsCRC
}

/// A class with unarchive function for xz archives.
public class XZArchive: Archive {

    struct ServiceInfo {

    }

    /**
     Unarchives xz archive stored in `archiveData`.

     If data passed is not actually a xz archive, `XZError` will be thrown.

     If data inside the archive is not actually compressed with LZMA algorithm, `LZMAError` will be thrown.

     - Parameter archiveData: Data compressed with xz.

     - Throws: `LZMAError` or `XZError` depending on the type of inconsistency in data.
     It may indicate that either the data is damaged or it might not be compressed with xz or LZMA at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archiveData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        // STREAM HEADER

        let magic = pointerData.intFromAlingedBytes(count: 6)
        guard magic == 0x005A587A37FD else { throw XZError.WrongMagic }

        guard pointerData.alignedByte() == 0 else { throw XZError.WrongFlagsFirstByte }

        let checkType = pointerData.intFromBits(count: 4)
        switch checkType {
        case 0x00, 0x01, 0x04, 0x0A:
            break
        default:
            throw XZError.WrongCheckType
        }

        guard pointerData.intFromBits(count: 4) == 0 else { throw XZError.WrongFlagsLastFourBits }

        let flagsCRC = pointerData.intFromAlingedBytes(count: 4)
        guard CheckSums.crc32([0, checkType.toUInt8()]) == flagsCRC else { throw XZError.WrongFlagsCRC }

        // STREAM FOOTER (Should be after parsing blocks).

        return try LZMA.decompress(&pointerData)
    }
    
}



