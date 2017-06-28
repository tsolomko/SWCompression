//
//  ZlibArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 30.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Represents an error, which happened during processing Zlib archive.
 It may indicate that either archive is damaged or it might not be Zlib archive at all.
 */
public enum ZlibError: Error {
    /// Compression method used in archive is different from Deflate, which is the only supported one.
    case wrongCompressionMethod
    /// Compression info has value incompatible with Deflate compression method.
    case wrongCompressionInfo
    /// First two bytes of archive's flags are inconsistent with each other.
    case wrongFcheck
    /// Compression level has value, which is different from the supported ones.
    case wrongCompressionLevel
    /**
     Computed checksum of uncompressed data doesn't match the value stored in archive.
     Associated value of the error contains already decompressed data.
    */
    case wrongAdler32(Data)
}

/// Represents a Zlib archive's header.
public struct ZlibHeader {

    /// Supported compression methods in zlib archive.
    public enum CompressionMethod: Int {
        /// The only one supported compression method (Deflate).
        case deflate = 8
    }

    /// Levels of compression which can be used to create Zlib archive.
    public enum CompressionLevel: Int {
        /// Fastest algorithm.
        case fastestAlgorithm = 0
        /// Fast algorithm.
        case fastAlgorithm = 1
        /// Default algorithm.
        case defaultAlgorithm = 2
        /// Slowest algorithm but with maximum compression.
        case slowAlgorithm = 3
    }

    /// Compression method of archive. Currently, always equals to `.deflate`.
    public let compressionMethod: CompressionMethod

    /// Level of compression used in archive.
    public let compressionLevel: CompressionLevel

    /// Size of 'window': moving interval of data which was used to make archive.
    public let windowSize: Int

    /**
     Initializes the structure with the values from Zlib `archive`.

     If data passed is not actually a Zlib archive, `ZlibError` will be thrown.

     - Parameter archive: Data archived with zlib.

     - Throws: `ZlibError`. It may indicate that either archive is damaged or
     it might not be archived with Zlib at all.
     */
    public init(archive data: Data) throws {
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        try self.init(&pointerData)
    }

    init(_ pointerData: inout DataWithPointer) throws {
        // First four bits are compression method.
        // Only compression method = 8 (DEFLATE) is supported.
        let compressionMethod = pointerData.intFromBits(count: 4)
        guard compressionMethod == 8 else { throw ZlibError.wrongCompressionMethod }

        self.compressionMethod = .deflate

        // Remaining four bits indicate window size.
        // For Deflate it must not be more than 7.
        let compressionInfo = pointerData.intFromBits(count: 4)
        guard compressionInfo <= 7 else { throw ZlibError.wrongCompressionInfo }
        let windowSize = 1 << (compressionInfo + 8)

        self.windowSize = windowSize

        // compressionMethod and compressionInfo combined are needed later for integrity check.
        let cmf = compressionInfo << 4 + compressionMethod

        // Next five bits are fcheck bits which are supposed to be integrity check.
        let fcheck = pointerData.intFromBits(count: 5)

        // Sixth bit indicate if archive contain Adler-32 checksum of preset dictionary.
        let fdict = pointerData.intFromBits(count: 1)

        // Remaining bits indicate compression level.
        guard let compressionLevel = ZlibHeader.CompressionLevel(rawValue:
            pointerData.intFromBits(count: 2)) else { throw ZlibError.wrongCompressionLevel }

        self.compressionLevel = compressionLevel

        // fcheck, fdict and compresionLevel together make flags byte which is used in integrity check.
        let flags = compressionLevel.rawValue << 6 + fdict << 5 + fcheck
        guard (UInt(cmf) * 256 + UInt(flags)) % 31 == 0 else { throw ZlibError.wrongFcheck }

        // If preset dictionary is present 4 bytes will be skipped.
        if fdict == 1 {
            pointerData.index += 4
        }
    }

}

/// Provides unarchive and archive functions for Zlib archives.
public class ZlibArchive: Archive {

    /**
     Unarchives Zlib archive.

     If data passed is not actually a Zlib archive, `ZlibError` will be thrown.

     If data in archive is not actually compressed with Deflate algorithm, `DeflateError` will be thrown.
    
     - Note: This function is specification compliant.

     - Parameter archive: Data archived with Zlib.

     - Throws: `DeflateError` or `ZlibError` depending on the type of the problem.
     It may indicate that either archive is damaged or
     it might not be archived with Zlib or compressed with Deflate at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archive data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        _ = try ZlibHeader(&pointerData)

        let out = try Deflate.decompress(&pointerData)

        let adler32 = pointerData.intFromAlignedBytes(count: 4).reverseBytes()
        guard CheckSums.adler32(out) == adler32 else { throw ZlibError.wrongAdler32(Data(bytes: out)) }

        return Data(bytes: out)
    }

    /**
     Archives `data` into Zlib archive. 
     Data will be also compressed with Deflate algorithm.
     It will also be specified in archive's header that the compressor used the slowest Deflate algorithm.

     If during compression something goes wrong `DeflateError` will be thrown.

     - Note: This function is specification compliant.

     - Parameter data: Data to compress and archive.

     - Throws: `DeflateError` if an error was encountered during compression.

     - Returns: Resulting archive's data.
     */
    public static func archive(data: Data) throws -> Data {
        let out: [UInt8] = [
            120, // CM (Compression Method) = 8 (DEFLATE), CINFO (Compression Info) = 7 (32K window size).
            218 // Flags: slowest algorithm, no preset dictionary.
        ]
        var outData = Data(bytes: out)
        outData.append(try Deflate.compress(data: data))

        let adler32 = CheckSums.adler32(data)
        var adlerBytes = [UInt8]()
        for i in 0..<4 {
            adlerBytes.append(UInt8((adler32 & (0xFF << ((3 - i) * 8))) >> ((3 - i) * 8)))
        }
        outData.append(Data(bytes: adlerBytes))

        return outData
    }

}
