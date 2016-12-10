//
//  GzipArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 29.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during unarchiving gzip archive.
 It may indicate that either the data is damaged or it might not be gzip archive at all.

 - `WrongMagic`: first two bytes of archive were not 31 and 139.
 - `WrongCompressionMethod`: compression method was other than 8 which is the only supported one.
 - `NonZeroReservedFlags`: reserved flags bits were not equal to 0, which is bad.
 */
public enum GzipError: Error {
    /// First two bytes of archive were not 31 and 139.
    case WrongMagic
    /// Compression method was other than 8 which is the only supported one.
    case WrongCompressionMethod
    /// Reserved flags bits were not equal to 0, which is bad.
    case NonZeroReservedFlags
}

/// A class with unarchive function for gzip archives.
public class GzipArchive: Archive {

    struct Flags {
        static let ftext: UInt8 = 0x01
        static let fhcrc: UInt8 = 0x02
        static let fextra: UInt8 = 0x04
        static let fname: UInt8 = 0x08
        static let fcomment: UInt8 = 0x10
    }

    struct ServiceInfo: Equatable {

        let magic: Int
        let method: UInt8
        let flags: UInt8
        let mtime: Int
        let extraFlags: UInt8
        let osType: UInt8
        // Optional fields
        var fileName: String
        var comment: String
        var crc: Int

        public static func ==(lhs: ServiceInfo, rhs: ServiceInfo) -> Bool {
            return lhs.magic == rhs.magic && lhs.method == rhs.method &&
                lhs.flags == rhs.flags && lhs.mtime == rhs.mtime && lhs.extraFlags == rhs.extraFlags &&
                lhs.osType == rhs.osType && lhs.fileName == rhs.fileName &&
                lhs.comment == rhs.comment && lhs.crc == rhs.crc
        }
    }

    static func serviceInfo(archiveData: Data) throws -> ServiceInfo {
        let pointerData = DataWithPointer(data: archiveData, bitOrder: .reversed)
        return try serviceInfo(pointerData: pointerData)
    }

    static func serviceInfo(pointerData: DataWithPointer) throws -> ServiceInfo {
        // First two bytes should be correct 'magic' bytes
        let magic = pointerData.intFromBits(count: 16)
        guard magic == 0x8b1f else { throw GzipError.WrongMagic }

        // Third byte is a method of compression. Only type 8 (DEFLATE) compression is supported
        let method = pointerData.alignedByte()
        guard method == 8 else { throw GzipError.WrongCompressionMethod }

        // Next bytes present some service information
        var serviceInfo = ServiceInfo(magic: magic,
                                      method: method,
                                      flags: pointerData.alignedByte(),
                                      mtime: pointerData.intFromBits(count: 32),
                                      extraFlags: pointerData.alignedByte(),
                                      osType: pointerData.alignedByte(),
                                      fileName: "", comment: "", crc: 0)

        guard (serviceInfo.flags & 0x20 == 0) &&
            (serviceInfo.flags & 0x40 == 0) &&
            (serviceInfo.flags & 0x80 == 0) else { throw GzipError.NonZeroReservedFlags }

        // Some archives may contain extra fields
        if serviceInfo.flags & Flags.fextra != 0 {
            let xlen = pointerData.intFromBits(count: 16)
            pointerData.index += xlen
            // TODO: Add extra fields' processing
        }

        // Some archives may contain source file name (this part ends with zero byte)
        if serviceInfo.flags & Flags.fname != 0 {
            var fnameBytes: [UInt8] = []
            while true {
                let byte = pointerData.alignedByte()
                guard byte != 0 else { break }
                fnameBytes.append(byte)
            }
            serviceInfo.fileName = String(data: Data(fnameBytes), encoding: .utf8) ?? ""
        }

        // Some archives may contain comment (this part also ends with zero)
        if serviceInfo.flags & Flags.fcomment != 0 {
            var fcommentBytes: [UInt8] = []
            while true {
                let byte = pointerData.alignedByte()
                guard byte != 0 else { break }
                fcommentBytes.append(byte)
            }
            serviceInfo.comment = String(data: Data(fcommentBytes), encoding: .utf8) ?? ""
        }

        // Some archives may contain 2-bytes checksum
        if serviceInfo.flags & Flags.fhcrc != 0 {
            serviceInfo.crc = pointerData.intFromBits(count: 16)
        }

        return serviceInfo
    }

    /**
     Unarchives gzip archive stored in `archiveData`.

     If data passed is not actually a gzip archive, `GzipError` will be thrown.

     If data inside the archive is not actually compressed with DEFLATE algorithm, `DeflateError` will be thrown.

     - Note: This function is specification compliant.

     - Parameter archiveData: Data compressed with gzip.

     - Throws: `DeflateError` or `GzipError` depending on the type of inconsistency in data.
     It may indicate that either the data is damaged or it might not be compressed with gzip or DEFLATE at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archiveData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        _ = try serviceInfo(pointerData: pointerData)
        return try Deflate.decompress(pointerData: pointerData)
        // TODO: Add crc check
    }

}
