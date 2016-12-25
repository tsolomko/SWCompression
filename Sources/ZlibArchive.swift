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

 - `WrongCompressionMethod`: unsupported compression method (not 8).
 - `WrongCompressionInfo`: unsupported compression info (greater than 7).
 - `WrongFcheck`: first two bytes were inconsistent with each other.
 - `WrongCompressionLevel`: unsupported compression level (not 0, 1, 2 or 3).
 - `WrongAdler32`: computed Adler-32 checksum of uncompressed data didn't match the archive's value.
    Associated value contains already decompressed data.
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
    /**
        Computed Adler-32 sum of uncompressed data didn't match the value stored in the archive.
        Associated value contains already decompressed data.
    */
    case WrongAdler32(Data)
}

/// A strucutre which provides information about zlib archive.
public struct ZlibHeader {

    /// Supported compression methods in zlib archive.
    public enum CompressionMethod: Int {
        case deflate = 8
    }

    /// Levels of compression which can be used to create zlib archive.
    public enum CompressionLevel: Int {
        case fastestAlgorithm = 0
        case fastAlgorithm = 1
        case defaultAlgorithm = 2
        case slowAlgorithm = 3
    }

    /// Compression method of archive. Always equals to `.deflate`.
    public let compressionMethod: CompressionMethod
    /// Level of compression in the archive.
    public let compressionLevel: CompressionLevel
    /// Size of 'window': moving interval of data which was used to make the archive
    public let windowSize: Int

    /**
     Initializes the structure with the values from zlib archive presented in `archiveData`.

     If data passed is not actually a zlib archive, `ZlibError` will be thrown.

     - Parameter archiveData: Data compressed with zlib.

     - Throws: `ZlibError`. It may indicate that either the data is damaged or
     it might not be compressed with zlib at all.
     */
    public init(archiveData: Data) throws {
        let pointerData = DataWithPointer(data: archiveData, bitOrder: .reversed)
        try self.init(pointerData)
    }

    init(_ pointerData: DataWithPointer) throws {
        // First four bits are compression method.
        // Only compression method = 8 (DEFLATE) is supported.
        let compressionMethod = pointerData.intFromBits(count: 4)
        guard compressionMethod == 8 else { throw ZlibError.WrongCompressionMethod }

        self.compressionMethod = .deflate

        // Remaining four bits indicate window size
        // For DEFLATE it must not be more than 7
        let compressionInfo = pointerData.intFromBits(count: 4)
        guard compressionInfo <= 7 else { throw ZlibError.WrongCompressionInfo }
        let windowSize = 1 << (compressionInfo + 8)

        self.windowSize = windowSize

        // compressionMethod and compressionInfo combined are needed later for integrity check
        let cmf = compressionInfo << 4 + compressionMethod

        // Next five bits are fcheck bits which are supposed to be integrity check
        let fcheck = pointerData.intFromBits(count: 5)

        // Sixth bit indicate if archive contain Adler-32 checksum of preset dictionary
        let fdict = pointerData.intFromBits(count: 1)

        // Remaining bits indicate compression level
        guard let compressionLevel = ZlibHeader.CompressionLevel(rawValue:
            pointerData.intFromBits(count: 2)) else { throw ZlibError.WrongCompressionLevel }

        self.compressionLevel = compressionLevel

        // fcheck, fdict and compresionLevel together make flags byte which is used in integrity check
        let flags = compressionLevel.rawValue << 6 + fdict << 5 + fcheck
        guard (UInt(cmf) * 256 + UInt(flags)) % 31 == 0 else { throw ZlibError.WrongFcheck }

        // If preset dictionary is present 4 bytes will be skipped
        if fdict == 1 {
            pointerData.index += 4
        }
    }

}

/// A class with unarchive function for Zlib archives.
public final class ZlibArchive: Archive {

    /**
     Unarchives Zlib archive stored in `archiveData`.

        If data passed is not actually a zlib archive, `ZlibError` will be thrown.

        If data inside the archive is not actually compressed with DEFLATE algorithm, `DeflateError` will be thrown.
    
     - Note: This function is specification compliant.

     - Parameter archiveData: Data compressed with zlib.

     - Throws: `DeflateError` or `ZlibError` depending on the type of inconsistency in data.
        It may indicate that either the data is damaged or it might not be compressed with zlib or DEFLATE at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archiveData data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        _ = try ZlibHeader(pointerData)

        let out = try Deflate.decompress(&pointerData)

        let adler32 = pointerData.intFromBits(count: 32).reverseBytes()
        guard CheckSums.adler32(out) == adler32 else { throw ZlibError.WrongAdler32(Data(bytes: out)) }

        return Data(bytes: out)
    }

}
