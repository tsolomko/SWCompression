// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides unarchive function for XZ archives.
public class XZArchive: Archive {

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
            let blockHeaderSize = pointerData.byte()
            if blockHeaderSize == 0 {
                indexSize = try processIndex(blockInfos, pointerData)
                break
            } else {
                let blockInfo = try processBlock(blockHeaderSize, pointerData)
                out.append(contentsOf: blockInfo.blockData)
                let checkSize: Int
                switch streamHeader.checkType {
                case 0x00:
                    checkSize = 0
                    break
                case 0x01:
                    checkSize = 4
                    let check = pointerData.uint32()
                    guard CheckSums.crc32(blockInfo.blockData) == check
                        else { throw XZError.wrongCheck(Data(bytes: out)) }
                case 0x04:
                    checkSize = 8
                    let check = pointerData.uint64()
                    guard CheckSums.crc64(blockInfo.blockData) == check
                        else { throw XZError.wrongCheck(Data(bytes: out)) }
                case 0x0A:
                    throw XZError.checkTypeSHA256
                default:
                    throw XZError.fieldReservedValue
                }
                blockInfos.append((blockInfo.unpaddedSize + checkSize, blockInfo.uncompressedSize))
            }
        }

        // STREAM FOOTER
        try processFooter(streamHeader, indexSize, pointerData)

        return Data(bytes: out)
    }

    private static func processStreamHeader(_ pointerData: DataWithPointer) throws -> (checkType: UInt8, flagsCRC: UInt32) {
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
        let checkType = flagsBytes[1] & 0x0F
        switch checkType {
        case 0x00, 0x01, 0x04, 0x0A:
            break
        default:
            throw XZError.fieldReservedValue
        }

        return (checkType, flagsCRC)
    }

    private static func processBlock(_ blockHeaderSize: UInt8,
                                     _ pointerData: DataWithPointer) throws -> (blockData: [UInt8], unpaddedSize: Int, uncompressedSize: Int) {
        var blockBytes: [UInt8] = []
        let blockHeaderStartIndex = pointerData.index - 1
        blockBytes.append(blockHeaderSize)
        guard blockHeaderSize >= 0x01 && blockHeaderSize <= 0xFF
            else { throw XZError.wrongFieldValue }
        let realBlockHeaderSize = (blockHeaderSize + 1) * 4

        let blockFlags = pointerData.byte()
        blockBytes.append(blockFlags)
        /**
         Bit values 00, 01, 10, 11 indicate filters number from 1 to 4,
         so we actually need to add 1 to get filters' number.
         */
        let numberOfFilters = blockFlags & 0x03 + 1
        guard blockFlags & 0x3C == 0
            else { throw XZError.fieldReservedValue }

        /// Should match size of compressed data.
        var compressedSize = -1
        if blockFlags & 0x40 != 0 {
            let compressedSizeDecodeResult = try pointerData.multiByteDecode()
            compressedSize = compressedSizeDecodeResult.multiByteInteger
            guard compressedSize > 0
                else { throw XZError.wrongFieldValue }
            blockBytes.append(contentsOf: compressedSizeDecodeResult.bytesProcessed)
        }

        /// Should match the size of data after decompression.
        var uncompressedSize = -1
        if blockFlags & 0x80 != 0 {
            let uncompressedSizeDecodeResult = try pointerData.multiByteDecode()
            uncompressedSize = uncompressedSizeDecodeResult.multiByteInteger
            guard uncompressedSize > 0
                else { throw XZError.wrongFieldValue }
            blockBytes.append(contentsOf: uncompressedSizeDecodeResult.bytesProcessed)
        }

        // TODO: First parse, then use.
        var filters: [(DataWithPointer) throws -> [UInt8]] = []
        for _ in 0..<numberOfFilters {
            let filterIDTuple = try pointerData.multiByteDecode()
            let filterID = filterIDTuple.multiByteInteger
            blockBytes.append(contentsOf: filterIDTuple.bytesProcessed)
            guard UInt64(filterID) < 0x4000000000000000
                else { throw XZError.wrongFilterID }
            // Only LZMA2 filter is supported.
            switch filterID {
            case 0x21: // LZMA2
                // First, we need to skip byte with the size of filter's properties
                blockBytes.append(contentsOf: try pointerData.multiByteDecode().bytesProcessed)
                /// In case of LZMA2 filters property is a dicitonary size.
                let filterPropeties = pointerData.byte()
                blockBytes.append(filterPropeties)
                let closure = { (dwp: DataWithPointer) -> [UInt8] in
                    try LZMA2.decompress(LZMA2.dictionarySize(filterPropeties), dwp)
                }
                filters.append(closure)
            default:
                throw XZError.wrongFilterID
            }
        }

        // We need to take into account 4 bytes for CRC32 so thats why "-4".
        while pointerData.index - blockHeaderStartIndex < realBlockHeaderSize.toInt() - 4 {
            let byte = pointerData.byte()
            guard byte == 0x00
                else { throw XZError.wrongPadding }
            blockBytes.append(byte)
        }

        let blockHeaderCRC = pointerData.uint32()
        guard CheckSums.crc32(blockBytes) == blockHeaderCRC
            else { throw XZError.wrongInfoCRC }

        var intResult = pointerData
        let compressedDataStart = pointerData.index
        for filterIndex in 0..<numberOfFilters - 1 {
            var arrayResult = try filters[numberOfFilters.toInt() - filterIndex.toInt() - 1](intResult)
            intResult = DataWithPointer(array: &arrayResult)
        }
        guard compressedSize == -1 || compressedSize == pointerData.index - compressedDataStart
            else { throw XZError.wrongDataSize }

        let out = try filters[numberOfFilters.toInt() - 1](intResult)
        guard uncompressedSize == -1 || uncompressedSize == out.count
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
        var indexBytes: [UInt8] = [0x00]
        let numberOfRecordsTuple = try pointerData.multiByteDecode()
        indexBytes.append(contentsOf: numberOfRecordsTuple.bytesProcessed)
        let numberOfRecords = numberOfRecordsTuple.multiByteInteger
        guard numberOfRecords == blockInfos.count
            else { throw XZError.wrongFieldValue }
        for blockInfo in blockInfos {
            let unpaddedSizeTuple = try pointerData.multiByteDecode()
            guard unpaddedSizeTuple.multiByteInteger == blockInfo.unpaddedSize
                else { throw XZError.wrongFieldValue }
            indexBytes.append(contentsOf: unpaddedSizeTuple.bytesProcessed)

            let uncompSizeTuple = try pointerData.multiByteDecode()
            guard uncompSizeTuple.multiByteInteger == blockInfo.uncompSize
                else { throw XZError.wrongDataSize }
            indexBytes.append(contentsOf: uncompSizeTuple.bytesProcessed)
        }

        if indexBytes.count % 4 != 0 {
            let paddingSize = 4 - indexBytes.count % 4
            for _ in 0..<paddingSize {
                let byte = pointerData.byte()
                guard byte == 0x00
                    else { throw XZError.wrongPadding }
                indexBytes.append(byte)
            }
        }

        let indexCRC = pointerData.uint32()
        guard CheckSums.crc32(indexBytes) == indexCRC
            else { throw XZError.wrongInfoCRC }

        return indexBytes.count + 4
    }

    private static func processFooter(_ streamHeader: (checkType: UInt8, flagsCRC: UInt32),
                                      _ indexSize: Int,
                                      _ pointerData: DataWithPointer) throws {
        let footerCRC = pointerData.uint32()
        let storedBackwardSize = pointerData.bytes(count: 4)
        let footerStreamFlags = pointerData.bytes(count: 2)
        guard CheckSums.crc32([storedBackwardSize, footerStreamFlags].flatMap { $0 }) == footerCRC
            else { throw XZError.wrongInfoCRC }

        /// Indicates the size of Index field. Should match its real size.
        var realBackwardSize = 0
        for i in 0..<4 {
            realBackwardSize |= storedBackwardSize[i].toInt() << (8 * i)
        }
        realBackwardSize += 1
        realBackwardSize *= 4
        guard realBackwardSize == indexSize
            else { throw XZError.wrongFieldValue }

        // Flags in the footer should be the same as in the header.
        guard footerStreamFlags[0] == 0
            else { throw XZError.fieldReservedValue }
        guard footerStreamFlags[1] & 0x0F == streamHeader.checkType
            else { throw XZError.wrongFieldValue }
        guard footerStreamFlags[1] & 0xF0 == 0
            else { throw XZError.fieldReservedValue }

        // Check footer's magic number
        guard pointerData.bytes(count: 2) == [0x59, 0x5A]
            else { throw XZError.wrongMagic }
    }

}

fileprivate extension DataWithPointer {

    // TODO: Removed `bytesProcessed`.
    fileprivate func multiByteDecode() throws -> (multiByteInteger: Int, bytesProcessed: [UInt8]) {
        var i = 1
        var result = self.byte().toInt()
        var bytes: [UInt8] = [result.toUInt8()]
        if result <= 127 {
            return (result, bytes)
        }
        result &= 0x7F
        while self.previousByte & 0x80 != 0 {
            let byte = self.byte()
            if i >= 9 || byte == 0x00 {
                throw XZError.multiByteIntegerError
            }
            bytes.append(byte)
            result += (byte.toInt() & 0x7F) << (7 * i)
            i += 1
        }
        return (result, bytes)
    }

}
