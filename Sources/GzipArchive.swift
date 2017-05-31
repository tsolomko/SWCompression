//
//  GzipArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 29.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

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

/// Represents a GZip archive's header.
public struct GzipHeader {

    struct Flags {
        static let ftext: UInt8 = 0x01
        static let fhcrc: UInt8 = 0x02
        static let fextra: UInt8 = 0x04
        static let fname: UInt8 = 0x08
        static let fcomment: UInt8 = 0x10
    }

    /// Supported compression methods in GZip archive.
    public enum CompressionMethod: Int {
        /// The only one supported compression method (Deflate).
        case deflate = 8
    }

    /// Type of file system on which GZip archive was created.
    public enum FileSystemType: Int {
        /**
         One of many UNIX-like systems.

         - Note: It seems like modern macOS systems also fall into this category.
         */
        case unix = 3
        /// Older Macintosh systems.
        case macintosh = 7
        /// File system used in Microsoft(TM)(R)(C) Windows(TM)(R)(C).
        case ntfs = 11
        /// File system was unknown to the archiver.
        case unknown = 255
        /// File system is one of the rare systems.
        case other = 256
    }

    /// Compression method of archive. Currently, always equals to `.deflate`.
    public let compressionMethod: CompressionMethod

    /**
     The most recent modification time of the original file. 
     If corresponding archive's field is set to 0, which means that no time was specified,
     then this property is `nil`.
     */
    public let modificationTime: Date?

    /// Type of file system on which archivation took place.
    public let osType: FileSystemType

    /// Name of the original file. If archive doesn't contain file's name, then `nil`.
    public let fileName: String?

    /// Comment stored in archive. If archive doesn't contain any comment, then `nil`.
    public let comment: String?

    /// Check if file is likely to be text file or ASCII-file.
    public let isTextFile: Bool

    /**
     Initializes the structure with the values from the first 'member' of GZip `archive`.

     If data passed is not actually a GZip archive, `GzipError` will be thrown.

     - Parameter archive: Data archived with GZip.

     - Throws: `GzipError`. It may indicate that either archive is damaged or
     it might not be archived with GZip at all.
    */
    public init(archive data: Data) throws {
        let pointerData = DataWithPointer(data: data, bitOrder: .reversed)
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
            self.fileName = String(data: Data(fnameBytes), encoding: .utf8)
        } else {
            self.fileName = nil
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

/// Provides unarchive and archive functions for GZip archives.
public class GzipArchive: Archive {

    /**
     Unarchives GZip archive.

     If data passed is not actually a GZip archive, `GzipError` will be thrown.

     If data in archive is not actually compressed with Deflate algorithm, `DeflateError` will be thrown.

     - Note: This function is specification compliant.

     - Parameter archive: Data archived with GZip.

     - Throws: `DeflateError` or `GzipError` depending on the type of the problem.
     It may indicate that either archive is damaged or
     it might not be archived with GZip or compressed with Deflate at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archive data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        _ = try GzipHeader(pointerData)

        let memberData = Data(bytes: try Deflate.decompress(&pointerData))

        let crc32 = pointerData.uint32FromAlignedBytes(count: 4)
        guard CheckSums.crc32(memberData) == crc32 else { throw GzipError.wrongCRC(memberData) }

        let isize = pointerData.intFromAlignedBytes(count: 4)
        guard UInt64(memberData.count) % UInt64(1) << 32 == UInt64(isize) else { throw GzipError.wrongISize }

        return memberData
    }

    /**
     Archives `data` into GZip archive, using various specified options.
     Data will be also compressed with Deflate algorithm.
     It will be also specified in archive's header that the compressor used the slowest Deflate algorithm.
     
     If during compression something goes wrong `DeflateError` will be thrown.
     If either `fileName` or `comment` cannot be encoded with ISO Latin-1 encoding,
     then `GzipError.cannotEncodeISOLatin1` will be thrown.

     - Note: This function is specification compliant.

     - Parameter data: Data to compress and archive.
     - Parameter comment: Additional comment, which will be stored as a separate field in archive.
     - Parameter fileName: Name of the file which will be archived.
     - Parameter writeHeaderCRC: Set to true, if you want to store consistency check for archive's header.
     - Parameter isTextFile: Set to true, if the file which will be archived is text file or ASCII-file.
     - Parameter osType: Type of the system on which this archive will be created.
     - Parameter modificationTime: Last time the file was modified.

     - Throws: `DeflateError` or `GzipError.cannotEncodeISOLatin1` depending on the type of of the problem.

     - Returns: Resulting archive's data.
     */
    public static func archive(data: Data, comment: String? = nil, fileName: String? = nil,
                               writeHeaderCRC: Bool = false, isTextFile: Bool = false,
                               osType: GzipHeader.FileSystemType? = nil, modificationTime: Date? = nil) throws -> Data {
        var flags: UInt8 = 0

        var commentData = Data()
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

        var fileNameData = Data()
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

        var os: UInt8 = 255
        if let osType = osType {
            os = (osType == .other ? 255 : osType.rawValue).toUInt8()
        }

        var mtimeBytes: [UInt8] = [0, 0, 0, 0]
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
