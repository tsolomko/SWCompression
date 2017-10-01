// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides unarchive function for XZ archives.
public class XZArchive: Archive {

    enum CheckType: Int {
        case none = 0x00
        case crc32 = 0x01
        case crc64 = 0x04
        case sha256 = 0x0A
    }

    /**
     Unarchives XZ archive.

     If data passed is not actually XZ archive, `XZError` will be thrown.
     Particularly, if filters other than LZMA2 are used in archive,
     then `XZError.wrongFilter` will be thrown.

     If an error happens during LZMA2 decompression,
     then `LZMAError` or `LZMA2Error` will be thrown.

     - Parameter archive: Data archived using XZ format.

     - Throws: `LZMAError`, `LZMA2Error` or `XZError` depending on the type of the problem.
     It may indicate that either the archive is damaged or it might not be compressed with XZ or LZMA(2) at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archive data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        // First, we should check footer magic bytes.
        // If they are wrong, then file cannot be 'undamaged'.
        // But the file may end with padding, so we need to account for this.
        pointerData.index = pointerData.size - 1
        var paddingBytes = 0
        while true {
            let byte = pointerData.byte()
            if byte != 0 {
                if paddingBytes % 4 != 0 {
                    throw XZError.wrongPadding
                } else {
                    break
                }
            }
            paddingBytes += 1
            pointerData.index -= 2
        }
        pointerData.index -= 2
        guard pointerData.bytes(count: 2) == [0x59, 0x5A]
            else { throw XZError.wrongMagic }

        // Let's now go to the start of the file.
        pointerData.index = 0

        return try processStream(pointerData)

    }

    /**
     Unarchives XZ archive which contains one or more streams.

     - Note: `wrongCheck` error contains only last processed stream's data as their associated value
     instead of all successfully processed members.
     This is a known issue and it will be fixed in future major version
     because solution requires backwards-incompatible API changes.

     - Parameter archive: XZ archive with one or more streams.

     - Throws: `LZMAError`, `LZMA2Error` or `XZError` depending on the type of the problem.
     It may indicate that one of the streams of archive is damaged or
     it might not be archived with XZ or LZMA(2) at all.

     - Returns: Unarchived data.
     */
    public static func multiUnarchive(archive data: Data) throws -> [Data] {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        // Note: for multi-stream archives we don't check footer's magic bytes,
        //  because it is impossible to determine the end of each stream
        //  without processing them, and checking last stream's footer doesn't
        //  guarantee correctness of other streams.

        var result = [Data]()
        streamLoop: while !pointerData.isAtTheEnd {
            result.append(try processStream(pointerData))

            guard !pointerData.isAtTheEnd else { break streamLoop }

            // STREAM PADDING
            var paddingBytes = 0
            while true {
                let byte = pointerData.byte()
                if byte != 0 {
                    if paddingBytes % 4 != 0 {
                        throw XZError.wrongPadding
                    } else {
                        break
                    }
                }
                if pointerData.isAtTheEnd {
                    if byte != 0 || paddingBytes % 4 != 3 {
                        throw XZError.wrongPadding
                    } else {
                        break streamLoop
                    }
                }
                paddingBytes += 1
            }
            pointerData.index -= 1
        }

        return result
    }

    private static func processStream(_ pointerData: DataWithPointer) throws -> Data {
        var out: [UInt8] = []

        // STREAM HEADER
        let streamHeader = try processStreamHeader(pointerData)

        // BLOCKS AND INDEX
        /// Zero value of blockHeaderSize means that we encountered INDEX.
        var blockInfos: [(unpaddedSize: Int, uncompSize: Int)] = []
        var indexSize = -1
        while true {
            let blockHeaderSize = pointerData.byte().toInt()
            if blockHeaderSize == 0 {
                indexSize = try processIndex(blockInfos, pointerData)
                break
            } else {
                let blockInfo = try processBlock(blockHeaderSize, pointerData)
                out.append(contentsOf: blockInfo.blockData)
                let checkSize: Int
                switch streamHeader.checkType {
                case .none:
                    checkSize = 0
                    break
                case .crc32:
                    checkSize = 4
                    let check = pointerData.uint32()
                    guard CheckSums.crc32(blockInfo.blockData) == check
                        else { throw XZError.wrongCheck(Data(bytes: out)) }
                case .crc64:
                    checkSize = 8
                    let check = pointerData.uint64()
                    guard CheckSums.crc64(blockInfo.blockData) == check
                        else { throw XZError.wrongCheck(Data(bytes: out)) }
                case .sha256:
                    throw XZError.checkTypeSHA256
                }
                blockInfos.append((blockInfo.unpaddedSize + checkSize, blockInfo.uncompressedSize))
            }
        }

        // STREAM FOOTER
        try processFooter(streamHeader, indexSize, pointerData)

        return Data(bytes: out)
    }

    private static func processStreamHeader(_ pointerData: DataWithPointer) throws -> (checkType: CheckType, flagsCRC: UInt32) {
        // Check magic number.
        guard pointerData.bytes(count: 6) == [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]
            else { throw XZError.wrongMagic }

        let flagsBytes = pointerData.bytes(count: 2)

        // First, we need to check for corruption in flags,
        //  so we compare CRC32 of flags to the value stored in archive.
        let flagsCRC = pointerData.uint32()
        guard CheckSums.crc32(flagsBytes) == flagsCRC
            else { throw XZError.wrongInfoCRC }

        // If data is not corrupted, then some bits must be equal to zero.
        guard flagsBytes[0] == 0 && flagsBytes[1] & 0xF0 == 0
            else { throw XZError.fieldReservedValue }

        // Four bits of second flags byte indicate type of redundancy check.
        guard let checkType = CheckType(rawValue: flagsBytes[1].toInt() & 0xF)
            else { throw XZError.fieldReservedValue }

        return (checkType, flagsCRC)
    }

    private static func processBlock(_ blockHeaderSize: Int,
                                     _ pointerData: DataWithPointer) throws -> (blockData: [UInt8], unpaddedSize: Int, uncompressedSize: Int) {
        let blockHeaderStartIndex = pointerData.index - 1
        guard blockHeaderSize >= 0x01 && blockHeaderSize <= 0xFF
            else { throw XZError.wrongFieldValue }
        let realBlockHeaderSize = (blockHeaderSize + 1) * 4

        let blockFlags = pointerData.byte()
        /**
         Bit values 00, 01, 10, 11 indicate filters number from 1 to 4,
         so we actually need to add 1 to get filters' number.
         */
        let filtersCount = blockFlags & 0x03 + 1
        guard blockFlags & 0x3C == 0
            else { throw XZError.fieldReservedValue }

        /// Should match size of compressed data.
        let compressedSize = blockFlags & 0x40 != 0 ? try pointerData.multiByteDecode() : -1

        /// Should match the size of data after decompression.
        let uncompressedSize = blockFlags & 0x80 != 0 ? try pointerData.multiByteDecode() : -1

        var filters: [(DataWithPointer) throws -> [UInt8]] = []
        for _ in 0..<filtersCount {
            let filterID = try pointerData.multiByteDecode()
            guard UInt64(filterID) < 0x4000000000000000
                else { throw XZError.wrongFilterID }
            // Only LZMA2 filter is supported.
            if filterID == 0x21 {
                // First, we need to skip byte with the size of filter's properties
                _ = try pointerData.multiByteDecode()
                /// In case of LZMA2 filters property is a dicitonary size.
                let filterPropeties = pointerData.byte()
                let closure = { (dwp: DataWithPointer) -> [UInt8] in
                    try LZMA2.decompress(LZMA2.dictionarySize(filterPropeties), dwp)
                }
                filters.append(closure)
            } else {
                throw XZError.wrongFilterID
            }
        }

        // We need to take into account 4 bytes for CRC32 so thats why "-4".
        while pointerData.index - blockHeaderStartIndex < realBlockHeaderSize - 4 {
            let byte = pointerData.byte()
            guard byte == 0x00
                else { throw XZError.wrongPadding }
        }

        let blockHeaderCRC = pointerData.uint32()
        pointerData.index = blockHeaderStartIndex
        guard CheckSums.crc32(pointerData.bytes(count: realBlockHeaderSize - 4)) == blockHeaderCRC
            else { throw XZError.wrongInfoCRC }
        pointerData.index += 4

        var intResult = pointerData
        let compressedDataStart = pointerData.index
        for filterIndex in 0..<filtersCount - 1 {
            var arrayResult = try filters[filtersCount.toInt() - filterIndex.toInt() - 1](intResult)
            intResult = DataWithPointer(array: &arrayResult)
        }
        guard compressedSize < 0 || compressedSize == pointerData.index - compressedDataStart
            else { throw XZError.wrongDataSize }

        let out = try filters[filtersCount.toInt() - 1](intResult)
        guard uncompressedSize < 0 || uncompressedSize == out.count
            else { throw XZError.wrongDataSize }

        let unpaddedSize = pointerData.index - blockHeaderStartIndex

        if unpaddedSize % 4 != 0 {
            let paddingSize = 4 - unpaddedSize % 4
            for _ in 0..<paddingSize {
                let byte = pointerData.byte()
                guard byte == 0x00
                    else { throw XZError.wrongPadding }
            }
        }

        return (out, unpaddedSize, out.count)
    }

    private static func processIndex(_ blockInfos: [(unpaddedSize: Int, uncompSize: Int)],
                                     _ pointerData: DataWithPointer) throws -> Int {
        let indexStartIndex = pointerData.index - 1
        let recordsCount = try pointerData.multiByteDecode()
        guard recordsCount == blockInfos.count
            else { throw XZError.wrongFieldValue }

        for blockInfo in blockInfos {
            let unpaddedSize = try pointerData.multiByteDecode()
            guard unpaddedSize == blockInfo.unpaddedSize
                else { throw XZError.wrongFieldValue }

            let uncompSize = try pointerData.multiByteDecode()
            guard uncompSize == blockInfo.uncompSize
                else { throw XZError.wrongDataSize }
        }

        var indexSize = pointerData.index - indexStartIndex
        if indexSize % 4 != 0 {
            let paddingSize = 4 - indexSize % 4
            for _ in 0..<paddingSize {
                let byte = pointerData.byte()
                guard byte == 0x00
                    else { throw XZError.wrongPadding }
                indexSize += 1
            }
        }

        let indexCRC = pointerData.uint32()
        pointerData.index = indexStartIndex
        guard CheckSums.crc32(pointerData.bytes(count: indexSize)) == indexCRC
            else { throw XZError.wrongInfoCRC }
        pointerData.index += 4

        return indexSize + 4
    }

    private static func processFooter(_ streamHeader: (checkType: CheckType, flagsCRC: UInt32),
                                      _ indexSize: Int,
                                      _ pointerData: DataWithPointer) throws {
        let footerCRC = pointerData.uint32()
        /// Indicates the size of Index field. Should match its real size.
        let backwardSize = (pointerData.uint32().toInt() + 1 ) * 4
        let streamFooterFlags = pointerData.uint16().toInt()

        pointerData.index -= 6
        guard CheckSums.crc32(pointerData.bytes(count: 6)) == footerCRC
            else { throw XZError.wrongInfoCRC }

        guard backwardSize == indexSize
            else { throw XZError.wrongFieldValue }

        // Flags in the footer should be the same as in the header.
        guard streamFooterFlags & 0xFF == 0
            else { throw XZError.fieldReservedValue }
        guard (streamFooterFlags & 0xF00) >> 8 == streamHeader.checkType.rawValue
            else { throw XZError.wrongFieldValue }
        guard streamFooterFlags & 0xF000 == 0
            else { throw XZError.fieldReservedValue }

        // Check footer's magic number
        guard pointerData.bytes(count: 2) == [0x59, 0x5A]
            else { throw XZError.wrongMagic }
    }

}

fileprivate extension DataWithPointer {

    fileprivate func multiByteDecode() throws -> Int {
        var i = 1
        var result = self.byte().toInt()
        if result <= 127 {
            return result
        }
        result &= 0x7F
        while self.previousByte & 0x80 != 0 {
            let byte = self.byte()
            if i >= 9 || byte == 0x00 {
                throw XZError.multiByteIntegerError
            }
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return result
    }

}
