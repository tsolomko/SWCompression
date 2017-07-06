// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

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
