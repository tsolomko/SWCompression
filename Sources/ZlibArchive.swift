//
//  ZlibArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 30.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during unarchiving Zlib archive.
 It may indicate that either the data is damaged or it might not be Zlib archive at all.

 - `WrongCompressionMethod`: compression method was other than 8 which is the only supported one.
 - `WrongCompressionInfo`: compression info was greater than 7 which is uncompatible number 8 compression method.
 - `WrongFcheck`: first two bytes were inconsistent with each other.
 - `WrongCompressionLevel`: compression level was other than 0, 1, 2, 3.
 */
public enum ZlibError: Error {
    /// Compression method was other than 8 which is the only supported one.
    case WrongCompressionMethod
    /// Compression info was greater than 7 which is uncompatible number 8 compression method.
    case WrongCompressionInfo
    /// First two bytes were inconsistent with each other.
    case WrongFcheck
    /// Compression level was other than 0, 1, 2, 3.
    case WrongCompressionLevel
}

/// A class with unarchive function for Zlib archives.
public class ZlibArchive: Archive {

    enum CompressionLevel: Int {
        case fastestAlgorithm = 0
        case fastAlgorithm = 1
        case defaultAlgorithm = 2
        case slowAlgorithm = 3
    }

    struct ServiceInfo: Equatable {

        let compressionMethod: UInt8
        let windowSize: Int
        let compressionLevel: CompressionLevel
        var startPoint: Int

        public static func ==(lhs: ServiceInfo, rhs: ServiceInfo) -> Bool {
            return lhs.compressionMethod == rhs.compressionMethod &&
                lhs.windowSize == rhs.windowSize &&
                lhs.compressionLevel == rhs.compressionLevel &&
                lhs.startPoint == rhs.startPoint
        }
        
    }

    static func serviceInfo(archiveData data: Data) throws -> ServiceInfo {
        // First byte is compression method and window size
        let cmf = data[0]

        // First four bits are compression method.
        // Only compression method = 8 (DEFLATE) is supported.
        let compressionMethod = convertToUInt8(uint8Array: cmf[0..<4])
        guard compressionMethod == 8 else { throw ZlibError.WrongCompressionMethod }

        // Remaining four bits indicate window size
        // For DEFLATE it must not be more than 7
        let compressionInfo = convertToUInt8(uint8Array: cmf[4..<8])
        guard compressionInfo <= 7 else { throw ZlibError.WrongCompressionInfo }
        let windowSize = Int(pow(Double(2), Double(compressionInfo + 8)))

        // Second byte is flags
        let flags = data[1]

        // Flags contain fcheck bits which are supposed to be integrity check
        guard (UInt(cmf) * 256 + UInt(flags)) % 31 == 0 else { throw ZlibError.WrongFcheck }

        // Fifth bit indicate if archive contain Adler-32 checksum of preset dictionary
        let fdict = flags[5]

        // Remaining bits indicate compression level
        guard let compressionLevel = CompressionLevel(rawValue:
            convertToInt(uint8Array: flags[6..<8])) else { throw ZlibError.WrongCompressionLevel }

        var info = ServiceInfo(compressionMethod: compressionMethod,
                               windowSize: windowSize,
                               compressionLevel: compressionLevel,
                               startPoint: 2)

        // If preset dictionary is present 4 bytes will be skipped
        if fdict == 1 {
            info.startPoint += 4
        }
        // TODO: Add parsing of preset dictionary

        return info
    }

    /**
     Unarchives Zlib archive stored in `archiveData`.

        If data passed is not actually a zlib archive, `ZlibError` will be thrown.

        If data inside the archive is not actually compressed with DEFLATE algorithm, `DeflateError` will be thrown.
     
     - Note: This function is NOT specification compliant because it does not checks ADLER-32 checksum and preset dicitionaries.

     - Parameter archiveData: Data compressed with zlib.

     - Throws: `DeflateError` or `ZlibError` depending on the type of inconsistency in data.
        It may indicate that either the data is damaged or it might not be compressed with zlib or DEFLATE at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archiveData data: Data) throws -> Data {
        let info = try serviceInfo(archiveData: data)
        return try Deflate.decompress(compressedData: Data(data[info.startPoint..<data.count]))
        // TODO: Add Adler-32 check
    }

}
