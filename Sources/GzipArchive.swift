// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides unarchive and archive functions for GZip archives.
public class GzipArchive: Archive {

    /// Represents a member of multi-member of GZip archive.
    public struct Member {

        /// GZip header of a member.
        public let header: GzipHeader

        /// Unarchived data from a member.
        public let data: Data

    }

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

        return try processMember(&pointerData).data
    }

    /**
     Unarchives multi-member GZip archive.
     Multi-member GZip archives are essentially several GZip archives following each other in a single file.

     - Note: `wrongCRC` error contains only last processed member's data as their associated value
     instead of all successfully processed members. 
     This is a known issue and it will be fixed in future major version
     because solution requires backwards-incompatible API changes.

     - Parameter archive: GZip archive with one or more members.

     - Throws: `DeflateError` or `GzipError` depending on the type of the problem.
     It may indicate that one of the members of archive is damaged or
     it might not be archived with GZip or compressed with Deflate at all.

     - Returns: Unarchived data.
     */
    public static func multiUnarchive(archive data: Data) throws -> [Member] {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        var result = [Member]()
        while !pointerData.isAtTheEnd {
            result.append(try processMember(&pointerData))
        }

        return result
    }

    private static func processMember(_ pointerData: inout DataWithPointer) throws -> Member {
        let header = try GzipHeader(&pointerData)

        let memberData = Data(bytes: try Deflate.decompress(&pointerData))

        let crc32 = pointerData.uint32FromAlignedBytes(count: 4)
        guard CheckSums.crc32(memberData) == crc32 else { throw GzipError.wrongCRC(memberData) }

        let isize = pointerData.intFromAlignedBytes(count: 4)
        guard UInt64(memberData.count) % UInt64(1) << 32 == UInt64(isize) else { throw GzipError.wrongISize }

        return Member(header: header, data: memberData)
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
