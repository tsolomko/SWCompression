// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class SevenZipContainer: Container {

    static let signatureHeaderSize = 32

    public static func open(container data: Data) throws -> [ContainerEntry] {
        var entries = [SevenZipEntry]()
        let header = try readHeader(data)

        guard let files = header.fileInfo?.files
            else { return [] }

        /// Index of currently opened folder in `streamInfo.coderInfo.folders`.
        var folderIndex = 0

        /// Index of currently extracted file in `headerInfo.fileInfo.files`.
        var fileInFolderCount = 0

        /// Index of currently read stream.
        var streamIndex = -1

        var oldStreamIndex = -1

        /// Index of current stream for folder in `folder.packedStreams`.
        var folderStreamIndex = -1

        /// Total size of unpacked data for current folder. Used for consistency check.
        var folderUnpackSize = 0

        /// Total size of read data for current stream. Used for consistency check.
        var streamPackSize = 0

        var folderCRC = CheckSums.crc32(Data())
        var streamCRC = CheckSums.crc32(Data())

        let pointerData = DataWithPointer(data: data)

        for fileIndex in 0..<files.count {
            let file = files[fileIndex]
            let info: SevenZipEntryInfo
            let data: Data
            if !file.isEmptyStream {
                // Without `SevenZipStreamInfo` and `SevenZipPackInfo` objects,
                //  we cannot find file data location in container.
                guard let streamInfo = header.mainStreams
                    else { throw SevenZipError.noStreamFound }
                guard let packInfo = streamInfo.packInfo
                    else { throw SevenZipError.noPackInfoFound }
                // Check if there is enough folders.
                guard folderIndex < streamInfo.coderInfo.numFolders
                    else { throw SevenZipError.notEnoughFolders }

                /// Offset to the beginning of all stored data.
                let packOffset = signatureHeaderSize + packInfo.packPosition

                /// Folder, which contains current file.
                let folder = streamInfo.coderInfo.folders[folderIndex]

                // There may be several streams corresponding to a single folder,
                //  so we have to iterate over them, if necessary.
                var streamChanged = false
                if folderStreamIndex == -1 {
                    // We need to open (start) new folder.
                    folderStreamIndex += 1
                    oldStreamIndex = streamIndex
                    streamIndex = folder.packedStreams[folderStreamIndex]
                    streamChanged = true
                } else if streamPackSize >= packInfo.packSizes[streamIndex] {
                    // We already have opened folder, but we need to go to the next stream.
                    guard streamPackSize == packInfo.packSizes[streamIndex]
                        else { throw SevenZipError.streamOverread }
                    folderStreamIndex += 1
                    guard folderStreamIndex < folder.numPackedStreams
                        else { throw SevenZipError.notEnoughStreams }
                    oldStreamIndex = streamIndex
                    streamIndex = folder.packedStreams[folderStreamIndex]
                    streamChanged = true
                }

                if streamChanged { // We need to move to the stream's offset if we switched streams.
                    pointerData.index = packOffset
                    if oldStreamIndex > -1 {
                        // If there was a processed stream already, we check its CRC.
                        if oldStreamIndex < packInfo.digests.count,
                            let storedStreamCRC = packInfo.digests[oldStreamIndex] {
                            guard streamCRC == storedStreamCRC
                                else { throw SevenZipError.wrongCRC }
                        }
                    }
                    // Reset information about old CRC.
                    oldStreamIndex = -1
                    streamCRC = CheckSums.crc32(Data())
                    if streamIndex != 0 {
                        for i in 0..<streamIndex {
                            pointerData.index += packInfo.packSizes[i]
                        }
                    }
                }

                var filePointerData = DataWithPointer(data: pointerData.data)
                filePointerData.index = pointerData.index
                var fileEndIndex = -1

                for coder in folder.orderedCoders() {
                    guard coder.numInStreams == 1 || coder.numOutStreams == 1
                        else { throw SevenZipError.multiStreamNotSupported }

                    let unpackSize = folder.unpackSize(for: coder)

                    let decodedData: Data
                    // TODO: Copy filter.
                    if coder.id == SevenZipCoder.ID.lzma2 {
                        // Dictionary size is stored in coder's properties.
                        guard let properties = coder.properties
                            else { throw SevenZipError.wrongCoderProperties }
                        guard properties.count == 1
                            else { throw SevenZipError.wrongCoderProperties }

                        decodedData = Data(bytes: try LZMA2.decompress(LZMA2.dictionarySize(properties[0]),
                                                                       filePointerData))
                    } else if coder.id == SevenZipCoder.ID.lzma {
                        // Both properties' byte (lp, lc, pb) and dictionary size are stored in coder's properties.
                        guard let properties = coder.properties
                            else { throw SevenZipError.wrongCoderProperties }
                        guard properties.count == 5
                            else { throw SevenZipError.wrongCoderProperties }

                        let lzmaDecoder = try LZMADecoder(filePointerData)

                        var dictionarySize = 0
                        for i in 1..<4 {
                            dictionarySize |= properties[i].toInt() << (8 * (i - 1))
                        }

                        try lzmaDecoder.decodeLZMA(unpackSize, properties[0], dictionarySize)
                        decodedData = Data(bytes: lzmaDecoder.out)
                    } else {
                        throw SevenZipError.compressionNotSupported
                    }

                    guard decodedData.count == unpackSize
                        else { throw SevenZipError.wrongDataSize }

                    // Save file's data end index after first pass.
                    // Necessary to calculate and check packed size later.
                    if fileEndIndex == -1 {
                        fileEndIndex = filePointerData.index
                    }

                    filePointerData = DataWithPointer(data: decodedData)
                }
                data = filePointerData.data

                // Update calculated folder's unpacked and stream's packed sizes.
                streamPackSize += fileEndIndex - pointerData.index
                folderUnpackSize += data.count

                // Update calculated folder's and stream's CRCs.
                folderCRC = CheckSums.crc32(data, prevValue: folderCRC)
                streamCRC = CheckSums.crc32(pointerData.bytes(count: fileEndIndex - pointerData.index),
                                            prevValue: streamCRC)

                let calculatedFileCRC = CheckSums.crc32(data)
                // `SevenZipSubstreamInfo` object may contain information about file's size and/or CRC32,
                //   if SubstreamInfo is present at all.
                if let substreamInfo = streamInfo.substreamInfo {
                    guard fileIndex >= substreamInfo.unpackSizes.count ||
                        data.count == substreamInfo.unpackSizes[fileIndex]
                        else { throw SevenZipError.wrongDataSize }
                    guard fileIndex >= substreamInfo.digests.count ||
                        calculatedFileCRC == substreamInfo.digests[fileIndex]
                        else { throw SevenZipError.wrongCRC }
                }
                // Even if container doesn't have info about file's size and/or CRC32,
                //  we still can calculate them and store in `SevenZipEntryInfo` object.
                info = SevenZipEntryInfo(file, data.count, calculatedFileCRC)

                fileInFolderCount += 1

                if fileInFolderCount > folder.numUnpackSubstreams { // If we read all files in folder...
                    // We need to check folder's unpacked size as well as its CRC32 (if it is available).
                    guard folderUnpackSize == folder.unpackSize()
                        else { throw SevenZipError.wrongDataSize }
                    if let storedFolderCRC = folder.crc {
                        guard folderCRC == storedFolderCRC
                            else { throw SevenZipError.wrongCRC }
                    }
                    folderCRC = CheckSums.crc32(Data())
                    // Moving to the next folder.
                    folderIndex += 1
                    // Resetting files count for the next folder.
                    fileInFolderCount = 0
                    // Next folder will have its own stream.
                    folderStreamIndex = -1
                }
            } else {
                info = SevenZipEntryInfo(file)
                data = Data()
            }

            entries.append(SevenZipEntry(info, data))
        }

        return entries
    }

    public static func info(container data: Data) throws -> [SevenZipEntryInfo] {
        var entryInfos = [SevenZipEntryInfo]()
        let header = try readHeader(data)

        guard let files = header.fileInfo?.files
            else { return [] }

        var nonEmptyFileIndex = 0
        for file in files {
            if !file.isEmptyStream, let substreamInfo = header.mainStreams?.substreamInfo {
                entryInfos.append(SevenZipEntryInfo(file,
                                                    substreamInfo.unpackSizes[nonEmptyFileIndex],
                                                    substreamInfo.digests[nonEmptyFileIndex]))
                nonEmptyFileIndex += 1
            } else {
                entryInfos.append(SevenZipEntryInfo(file))
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
