//
//  GzipArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 29.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during unarchiving gzip archive.
 It may indicate that either the data is damaged or it might not be gzip archive at all.

 - `wrongMagic`: first two bytes of archive were not 31 and 139.
 - `wrongCompressionMethod`: unsupported compression method (not 8 aka Deflate).
 - `wrongFlags`: unsupported flags (reserved flags weren't 0).
 - `wrongHeaderCRC`: computed Cyclic Redundancy Check of archive's header
        didn't match the archive's value.
 - `wrongCRC`: computed Cyclic Redundancy Check of uncompressed data didn't match the archive's value.
    Associated value contains already decompressed data.
 - `wrongISize`: size of uncompressed data modulo 2^32 didn't match the archive's value.
 */
public enum GzipError: Error {
    /// First two bytes of archive were not 31 and 139.
    case wrongMagic
    /// Compression method was other than 8 which is the only supported one.
    case wrongCompressionMethod
    /// Reserved flags bits were not equal to 0.
    case wrongFlags
    /// Computed CRC of header didn't match the value stored in the archive.
    case wrongHeaderCRC
    /**
     Computed CRC of uncompressed data didn't match the value stored in the archive.
     Associated value contains already decompressed data.
     */
    case wrongCRC(Data)
    /// Computed isize didn't match the value stored in the archive.
    case wrongISize

    case cannotEncodeISOLatin1
}

/// A structure which provides information about gzip archive.
public struct GzipHeader {

    struct Flags {
        static let ftext: UInt8 = 0x01
        static let fhcrc: UInt8 = 0x02
        static let fextra: UInt8 = 0x04
        static let fname: UInt8 = 0x08
        static let fcomment: UInt8 = 0x10
    }

    /// Supported compression methods in gzip archive.
    public enum CompressionMethod: Int {
        /// The only one supported compression method (Deflate).
        case deflate = 8
    }

    /// Type of file system on which gzip archive was created.
    public enum FileSystemType: Int {
        /// One of many Linux systems. (It seems like modern macOS systems also fall into this category).
        case unix = 3
        /// Older Macintosh (Mac OS, OS X) systems.
        case macintosh = 7
        /// File system used in Microsoft(TM)(R)(C) Windows(TM)(R)(C).
        case ntfs = 11
        /// File system was unknown to the archiver.
        case unknown = 255
        /// File system was one of the rare systems.
        case other = 256
    }

    /// Compression method of archive. Always equals to `.deflate`.
    public let compressionMethod: CompressionMethod
    /// The most recent modification time of the original file. If set to 0 (default value == unset), then nil.
    public let modificationTime: Date?
    /// Type of file system on which compression took place.
    public let osType: FileSystemType
    /// Name of the original file.
    public let originalFileName: String?
    /// Comment inside the archive.
    public let comment: String?

    public let isTextFile: Bool

    /**
        Initializes the structure with the values of first 'member' in gzip archive presented in `archiveData`.

        If data passed is not actually a gzip archive, `GzipError` will be thrown.

        - Parameter archiveData: Data compressed with gzip.

        - Throws: `GzipError`. It may indicate that either the data is damaged or
        it might not be compressed with gzip at all.
    */
    public init(archiveData: Data) throws {
        let pointerData = DataWithPointer(data: archiveData, bitOrder: .reversed)
        try self.init(pointerData)
    }

    init(_ pointerData: DataWithPointer) throws {
        // First two bytes should be correct 'magic' bytes
        let magic = pointerData.intFromAlignedBytes(count: 2)
        guard magic == 0x8b1f else { throw GzipError.wrongMagic }
        var headerBytes: [UInt8] = [0x1f, 0x8b]

        // Third byte is a method of compression. Only type 8 (DEFLATE) compression is supported
        let method = pointerData.alignedByte()
        guard method == 8 else { throw GzipError.wrongCompressionMethod }
        headerBytes.append(method)

        self.compressionMethod = .deflate

        let flags = pointerData.alignedByte()
        guard (flags & 0x20 == 0) && (flags & 0x40 == 0) && (flags & 0x80 == 0) else { throw GzipError.wrongFlags }
        headerBytes.append(flags)

        let mtime = pointerData.intFromAlignedBytes(count: 4)
        for i in 0..<4 {
            headerBytes.append(((mtime & (0xFF << (i * 8))) >> (i * 8)).toUInt8())
        }
        self.modificationTime = mtime == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(mtime))

        let extraFlags = pointerData.alignedByte()
        headerBytes.append(extraFlags)

        self.osType = FileSystemType(rawValue: pointerData.alignedByte().toInt()) ?? .other
        headerBytes.append(self.osType.rawValue.toUInt8())

        self.isTextFile = flags & Flags.ftext != 0

        // Some archives may contain extra fields
        if flags & Flags.fextra != 0 {
            let xlen = pointerData.intFromAlignedBytes(count: 2)
            for i in 0..<2 {
                headerBytes.append(((xlen & (0xFF << (i * 8))) >> (i * 8)).toUInt8())
            }
            for _ in 0..<xlen {
                headerBytes.append(pointerData.alignedByte())
            }
        }

        // Some archives may contain source file name (this part ends with zero byte)
        if flags & Flags.fname != 0 {
            var fnameBytes: [UInt8] = []
            while true {
                let byte = pointerData.alignedByte()
                headerBytes.append(byte)
                guard byte != 0 else { break }
                fnameBytes.append(byte)
            }
            self.originalFileName = String(data: Data(fnameBytes), encoding: .utf8)
        } else {
            self.originalFileName = nil
        }

        // Some archives may contain comment (this part also ends with zero)
        if flags & Flags.fcomment != 0 {
            var fcommentBytes: [UInt8] = []
            while true {
                let byte = pointerData.alignedByte()
                headerBytes.append(byte)
                guard byte != 0 else { break }
                fcommentBytes.append(byte)
            }
            self.comment = String(data: Data(fcommentBytes), encoding: .utf8)
        } else {
            self.comment = nil
        }

        // Some archives may contain 2-bytes checksum
        if flags & Flags.fhcrc != 0 {
            // Note: it is not actual CRC-16, it is just two least significant bytes of CRC-32.
            let crc16 = UInt32(truncatingBitPattern: pointerData.uint64FromAlignedBytes(count: 2))
            let ourCRC32 = CheckSums.crc32(headerBytes)
            guard ourCRC32 & 0xFFFF == crc16 else { throw GzipError.wrongHeaderCRC }
        }
    }

}

/// Provides unarchive function for GZip archives.
public final class GzipArchive: Archive {

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
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        var out: [UInt8] = []

        while !pointerData.isAtTheEnd {
            _ = try GzipHeader(pointerData)

            let memberData = try Deflate.decompress(&pointerData)

            let crc32 = pointerData.uint32FromAlignedBytes(count: 4)
            guard CheckSums.crc32(memberData) == crc32 else { throw GzipError.wrongCRC(Data(bytes: out)) }

            let isize = pointerData.intFromAlignedBytes(count: 4)
            guard UInt64(memberData.count) % UInt64(1) << 32 == UInt64(isize) else { throw GzipError.wrongISize }

            out.append(contentsOf: memberData)
        }

        return Data(bytes: out)
    }

    /**
     Archives `data` into GZip archive. Data will be also compressed with DEFLTATE algorithm.
     Fields in the header of the resulting archive will be set to default values 
     (i.e. no mtime, no flags, no file name, unknown OS type). 
     It will be also specified that the compressor used slowest DEFLATE algorithm.
     
     If during compression something goes wrong `DeflateError` will be thrown.

     - Note: This function is specification compliant.

     - Parameter data: Data to compress and archive.

     - Throws: `DeflateError` if an error was encountered during compression.

     - Returns: Data object with resulting archive.
     */
    public static func archive(data: Data, comment: String? = nil, fileName: String? = nil,
                               writeHeaderCRC: Bool = false, isTextFile: Bool = false,
                               osType: GzipHeader.FileSystemType? = nil, modificationTime: Date? = nil) throws -> Data {
        var flags: UInt8 = 0

        var commentData = Data()
        var fileNameData = Data()
        var mtimeBytes: [UInt8] = [0, 0, 0, 0]
        var os: UInt8 = 255

        if var comment = comment {
            flags |= 1 << 4
            if comment.characters.last != "\u{00}" {
                comment.append("\u{00}")
            }
            if let data = comment.data(using: .isoLatin1) {
                commentData = data
            } else {
                throw GzipError.cannotEncodeISOLatin1
            }
        }

        if var fileName = fileName {
            flags |= 1 << 3
            if fileName.characters.last != "\u{00}" {
                fileName.append("\u{00}")
            }
            if let data = fileName.data(using: .isoLatin1) {
                fileNameData = data
            } else {
                throw GzipError.cannotEncodeISOLatin1
            }
        }

        if writeHeaderCRC {
            flags |= 1 << 1
        }

        if isTextFile {
            flags |= 1 << 0
        }

        if let osType = osType {
            os = (osType == .other ? 255 : osType.rawValue).toUInt8()
        }

        if let modificationTime = modificationTime {
            let timeInterval = Int(modificationTime.timeIntervalSince1970)
            for i in 0..<4 {
                mtimeBytes[i] = UInt8(truncatingBitPattern: (timeInterval & (0xFF << (i * 8))) >> (i * 8))
            }
        }

        var headerBytes: [UInt8] = [
            0x1f, 0x8b, // 'magic' bytes.
            8, // Compression method (DEFLATE).
            flags // Flags; currently no flags are set.
        ]
        for i in 0..<4 {
            headerBytes.append(mtimeBytes[i])
        }
        headerBytes.append(2) // Extra flags; 2 means that DEFLATE used slowest algorithm.
        headerBytes.append(os)

        var outData = Data(bytes: headerBytes)

        outData.append(fileNameData)
        outData.append(commentData)

        if writeHeaderCRC {
            let headerCRC = CheckSums.crc32(outData)
            for i: UInt32 in 0..<2 {
                outData.append(UInt8((headerCRC & (0xFF << (i * 8))) >> (i * 8)))
            }
        }

        outData.append(try Deflate.compress(data: data))

        let crc32 = CheckSums.crc32(data)
        var crcBytes = [UInt8]()
        for i: UInt32 in 0..<4 {
            crcBytes.append(UInt8((crc32 & (0xFF << (i * 8))) >> (i * 8)))
        }
        outData.append(Data(bytes: crcBytes))

        let isize = UInt64(data.count) % UInt64(1) << 32
        var isizeBytes = [UInt8]()
        for i: UInt64 in 0..<4 {
            isizeBytes.append(UInt8((isize & (0xFF << (i * 8))) >> (i * 8)))
        }
        outData.append(Data(bytes: isizeBytes))

        return outData
    }

}
