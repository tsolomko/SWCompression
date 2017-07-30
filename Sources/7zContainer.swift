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

        /// Index of current stream for folder in `folder.packedStreams`.
        var folderStreamIndex = -1

        /// Total size of unpacked data for current folder. Used for consistency check.
        var folderUnpackSize = 0

        /// Combined calculated CRC of entire folder == all files in folder.
        var folderCRC = CheckSums.crc32(Data())

        /// `DataWithPointer` object with unpacked stream's data.
        var rawFileData = DataWithPointer(data: Data())

        /**
         Total size of processed unpacked data for current stream.
         Used to decide when to switch streams.
        */
        var rawUnpackSize = 0

        let pointerData = DataWithPointer(data: data)

        for fileIndex in 0..<files.count {
            let file = files[fileIndex]
            let info: SevenZipEntryInfo
            let data: Data?

            if !file.isEmptyStream {
                // TODO: Does empty files need all this?

                // Without `SevenZipStreamInfo` and `SevenZipPackInfo` objects,
                //  we cannot find file data location in container.
                guard let streamInfo = header.mainStreams
                    else { throw SevenZipError.noStreamFound }
                guard let packInfo = streamInfo.packInfo
                    else { throw SevenZipError.noPackInfoFound }

                // SubstreamInfo is required to get files' data, and without it we can only return files' info.
                // Additionally, `SevenZipEntry.data()` will throw `SevenZipError.dataIsUnavailable` 
                //  for files which should have had data, but SubstreamInfo wasn't available.
                guard let substreamInfo = streamInfo.substreamInfo else {
                    info = SevenZipEntryInfo(file)
                    data = nil
                    continue
                }

                // Check if there is enough folders.
                guard folderIndex < streamInfo.coderInfo.numFolders
                    else { throw SevenZipError.notEnoughFolders }

                /// Folder, which contains current file.
                let folder = streamInfo.coderInfo.folders[folderIndex]

                // There may be several streams corresponding to a single folder,
                //  so we have to iterate over them, if necessary.
                // Moreover, one stream can contain data of several files,
                //  so we need to decode the stream first, then split it into files.
                var streamChanged = false
                if folderStreamIndex == -1 {
                    // We need to open (start) new folder.
                    folderStreamIndex += 1
                    streamIndex = folder.packedStreams[folderStreamIndex]
                    streamChanged = true
                } else if rawUnpackSize >= rawFileData.size {
                    // We already have opened folder, but we need to go to the next stream.
                    guard rawUnpackSize == rawFileData.size
                        else { throw SevenZipError.streamOverread }
                    folderStreamIndex += 1
                    guard folderStreamIndex < folder.numPackedStreams
                        else { throw SevenZipError.notEnoughStreams }
                    streamIndex = folder.packedStreams[folderStreamIndex]
                    streamChanged = true
                }

                if streamChanged { // We need to load the new stream if we switched streams.
                    // First, we move to the stream's offset.
                    // We don't have any guarantees that streams will be enountered in the same order,
                    //  as they are placed in the container. 
                    // Thus, we have to start moving to stream's offset from the beginning.
                    // (Maybe, this is incorrect and the order of streams is guaranteed).
                    pointerData.index = signatureHeaderSize + packInfo.packPosition // Pack offset.
                    if streamIndex != 0 {
                        for i in 0..<streamIndex {
                            pointerData.index += packInfo.packSizes[i]
                        }
                    }

                    // Load the stream.
                    let streamData = Data(bytes: pointerData.bytes(count: packInfo.packSizes[streamIndex]))

                    // Check stream's CRC, if it's available.
                    if streamIndex < packInfo.digests.count,
                        let storedStreamCRC = packInfo.digests[streamIndex] {
                        guard CheckSums.crc32(streamData) == storedStreamCRC
                            else { throw SevenZipError.wrongCRC }
                    }

                    // Now we need to unpack stream.
                    rawFileData = DataWithPointer(data: try folder.unpack(data: streamData))
                    rawUnpackSize = 0
                }

                // `SevenZipSubstreamInfo` object should contain information about file's size
                //   and also may contain information about file's CRC32.

                // File's unpack size is required to proceed. 
                // Next check ensures that we don't `unpackSizes` array's boundaries.
                guard fileIndex < substreamInfo.unpackSizes.count
                    else { throw SevenZipError.noFileSize }

                let fileSize = substreamInfo.unpackSizes[fileIndex]
                let fileData = Data(bytes: rawFileData.bytes(count: fileSize))

                let calculatedFileCRC = CheckSums.crc32(fileData)
                if fileIndex < substreamInfo.digests.count {
                    guard calculatedFileCRC == substreamInfo.digests[fileIndex]
                        else { throw SevenZipError.wrongCRC }
                }

                info = SevenZipEntryInfo(file, fileSize, calculatedFileCRC)
                data = fileData

                // Update folder's crc and unpack size.
                folderUnpackSize += fileSize
                folderCRC = CheckSums.crc32(fileData, prevValue: folderCRC)

                // Update unpackSize for stream.
                rawUnpackSize += fileSize

                fileInFolderCount += 1

                if fileInFolderCount > folder.numUnpackSubstreams { // If we read all files in folder...
                    // We need to check folder's unpacked size as well as its CRC32 (if it is available).
                    guard folderUnpackSize == folder.unpackSize()
                        else { throw SevenZipError.wrongDataSize }
                    if let storedFolderCRC = folder.crc {
                        guard folderCRC == storedFolderCRC
                            else { throw SevenZipError.wrongCRC }
                    }
                    // Resetting folder's crc and unpack size.
                    folderCRC = CheckSums.crc32(Data())
                    folderUnpackSize = 0
                    // Resetting files count for the next folder.
                    fileInFolderCount = 0
                    // Moving to the next folder.
                    folderIndex += 1
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
