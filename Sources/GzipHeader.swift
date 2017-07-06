// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

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
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)
        try self.init(&pointerData)
    }

    init(_ pointerData: inout DataWithPointer) throws {
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
            self.fileName = String(data: Data(fnameBytes), encoding: .isoLatin1)
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
            self.comment = String(data: Data(fcommentBytes), encoding: .isoLatin1)
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

