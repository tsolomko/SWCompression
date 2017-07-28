// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class SevenZipContainer: Container {

    static let signatureHeaderSize = 32

    public static func open(container data: Data) throws -> [ContainerEntry] {
        return []
    }

    public static func info(container data: Data) throws -> [SevenZipEntryInfo] {
        var entryInfos = [SevenZipEntryInfo]()
        let header = try readHeader(data)

        if let files = header.fileInfo?.files, let substreamInfo = header.mainStreams?.substreamInfo {
            var nonEmptyFileIndex = 0
            for file in files {
                if file.isEmptyStream {
                    entryInfos.append(SevenZipEntryInfo(file))
                } else {
                    entryInfos.append(SevenZipEntryInfo(file,
                                                        substreamInfo.unpackSizes[nonEmptyFileIndex],
                                                        substreamInfo.digests[nonEmptyFileIndex]))
                    nonEmptyFileIndex += 1
                }
            }
        }

        return entryInfos
    }

    private static func readHeader(_ data: Data) throws -> SevenZipHeader {
        /// Object with input data which supports convenient work with bit shifts.
        let bitReader = BitReader(data: data, bitOrder: .straight)

        // **SignatureHeader**

        // Check signature.
        guard bitReader.bytes(count: 6) == [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
            else { throw SevenZipError.wrongSignature }

        // Check archive version.
        guard bitReader.bytes(count: 2) == [0, 4] // 7zFormat.txt says it should be [0, 2] instead.
            else { throw SevenZipError.wrongVersion }

        let startHeaderCRC = bitReader.uint32()

        /// - Note: Relative to SignatureHeader
        let nextHeaderOffset = Int(bitReader.uint64())
        let nextHeaderSize = Int(bitReader.uint64())
        let nextHeaderCRC = bitReader.uint32()

        bitReader.index = 12
        guard CheckSums.crc32(bitReader.bytes(count: 20)) == startHeaderCRC
            else { throw SevenZipError.wrongStartHeaderCRC }

        // **Header**
        bitReader.index += nextHeaderOffset
        let headerStartIndex = bitReader.index
        let headerEndIndex: Int

        let type = bitReader.byte()
        let header: SevenZipHeader

        if type == 0x17 {
            let packedHeaderStreamInfo = try SevenZipStreamInfo(bitReader)
            headerEndIndex = bitReader.index
            header = try SevenZipHeader(bitReader, using: packedHeaderStreamInfo)
        } else if type == 0x01 {
            header = try SevenZipHeader(bitReader)
            headerEndIndex = bitReader.index
        } else {
            throw SevenZipError.wrongPropertyID
        }

        // Check header size
        guard headerEndIndex - headerStartIndex == nextHeaderSize
            else { throw SevenZipError.wrongHeaderSize }

        // Check header CRC
        bitReader.index = headerStartIndex
        guard CheckSums.crc32(bitReader.bytes(count: nextHeaderSize)) == nextHeaderCRC
            else { throw SevenZipError.wrongHeaderCRC }

        return header
    }

}

extension BitReader {

    /// Abbreviation for "sevenZipMultiByteDecode".
    func szMbd() -> Int {
        let firstByte = self.byte().toInt()
        var mask = 0x80
        var value = 0
        for i in 0..<8 {
            if firstByte & mask == 0 {
                value |= ((firstByte & (mask &- 1)) << (8 * i))
                break
            }
            value |= self.byte().toInt() << (8 * i)
            mask >>= 1
        }
        return value
    }

    func defBits(count: Int) -> [UInt8] {
        let allDefined = self.byte()
        let definedBits: [UInt8]
        if allDefined == 0 {
            definedBits = self.bits(count: count)
        } else {
            definedBits = Array(repeating: 1, count: count)
        }
        return definedBits
    }

}
