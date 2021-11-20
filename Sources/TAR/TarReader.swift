// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

public struct TarReader {

    private let handle: FileHandle
    private var lastGlobalExtendedHeader: TarExtendedHeader?
    private var lastLocalExtendedHeader: TarExtendedHeader?
    private var longLinkName: String?
    private var longName: String?

    public init(fileHandle: FileHandle) {
        self.handle = fileHandle
    }

    public mutating func next() throws -> TarEntry? {
        let headerData = try getChunk()
        if headerData.count == 0 {
            return nil
        } else if headerData == Data(count: 512) {
            // EOF marker case.
            let offset: UInt64
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                offset = try handle.offset()
            } else {
                offset = handle.offsetInFile
            }
            if try getChunk() == Data(count: 512) {
                return nil
            } else {
                if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                    try handle.seek(toOffset: offset)
                } else {
                    handle.seek(toFileOffset: offset)
                }
            }
        } else if headerData.count < 512 {
            throw DataError.truncated
        }
        assert(headerData.count == 512)

        let header = try TarHeader(LittleEndianByteReader(data: headerData))
        // Since we read input in 512 bytes-long chunks, we don't have to check that we processed at most 512 bytes.
        // Check, just in case, since we use blockStartIndex = -1 when creating TAR containers.
        assert(header.blockStartIndex >= 0)

        let entryData = try getData(size: header.size)
        // Since we read input in 512 bytes-long chunks we don't have to round up the size as we do in TarParser.
        if case .special(let specialEntryType) = header.type {
            switch specialEntryType {
            case .globalExtendedHeader:
                lastGlobalExtendedHeader = try TarExtendedHeader(entryData)
            case .sunExtendedHeader:
                fallthrough
            case .localExtendedHeader:
                lastLocalExtendedHeader = try TarExtendedHeader(entryData)
            case .longLinkName:
                longLinkName = LittleEndianByteReader(data: entryData).tarCString(maxLength: header.size)
            case .longName:
                longName = LittleEndianByteReader(data: entryData).tarCString(maxLength: header.size)
            }
            return try next()
        } else {
            let info = TarEntryInfo(header, lastGlobalExtendedHeader, lastLocalExtendedHeader, longName, longLinkName)
            lastLocalExtendedHeader = nil
            longName = nil
            longLinkName = nil
            return TarEntry(info: info, data: entryData)
        }
    }

    private func getChunk() throws -> Data {
        let chunk: Data
        if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
            guard let chunkData = try handle.read(upToCount: 512)
                else { throw DataError.truncated }
            chunk = chunkData
        } else {
            // Technically, this can throw NSException, but since it is ObjC exception we cannot handle it in Swift.
            chunk = handle.readData(ofLength: 512)
        }
        return chunk
    }

    private func getData(size: Int) throws -> Data {
        var out = Data()
        var remainingSize = size
        while remainingSize > 0 {
            let chunk = try getChunk()
            guard chunk.count > 0
                else { throw DataError.truncated }
            out.append(chunk)
            remainingSize -= chunk.count
        }
        return out.dropLast(max(out.count - size, 0))
    }

}
