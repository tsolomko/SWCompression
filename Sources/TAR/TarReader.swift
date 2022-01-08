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
        self.lastGlobalExtendedHeader = nil
        self.lastLocalExtendedHeader = nil
        self.longLinkName = nil
        self.longName = nil
    }

    public mutating func read() throws -> TarEntry? {
        let headerData = try getData(size: 512)
        if headerData.count == 0 {
            return nil
        } else if headerData == Data(count: 512) {
            // EOF marker case.
            let offset = try getOffset()
            if try getData(size: 512) == Data(count: 512) {
                return nil
            } else {
                try set(offset: offset)
            }
        } else if headerData.count < 512 {
            throw DataError.truncated
        }
        assert(headerData.count == 512)

        let header = try TarHeader(LittleEndianByteReader(data: headerData))
        // Since we explicitly initialize the header from 512 bytes-long Data, we don't have to check that we processed
        // at most 512 bytes.
        // Check, just in case, since we use blockStartIndex = -1 when creating TAR containers.
        assert(header.blockStartIndex >= 0)
        let dataStartOffset = try getOffset()

        let entryData = try getData(size: header.size)
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
            try set(offset: dataStartOffset + UInt64(truncatingIfNeeded: header.size.roundTo512()))
            return try read()
        } else {
            let info = TarEntryInfo(header, lastGlobalExtendedHeader, lastLocalExtendedHeader, longName, longLinkName)
            try set(offset: dataStartOffset + UInt64(truncatingIfNeeded: header.size.roundTo512()))
            lastLocalExtendedHeader = nil
            longName = nil
            longLinkName = nil
            return TarEntry(info: info, data: entryData)
        }
    }

    private func getOffset() throws -> UInt64 {
        #if compiler(<5.2)
            return handle.offsetInFile
        #else
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                return try handle.offset()
            } else {
                return handle.offsetInFile
            }
        #endif
    }

    private func set(offset: UInt64) throws {
        #if compiler(<5.2)
            handle.seek(toFileOffset: offset)
        #else
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                try handle.seek(toOffset: offset)
            } else {
                handle.seek(toFileOffset: offset)
            }
        #endif
    }

    private func getData(size: Int) throws -> Data {
        assert(size >= 0, "TarReader.getData(size:): negative size.")
        guard size > 0
            else { return Data() }
        #if compiler(<5.2)
            return handle.readData(ofLength: size)
        #else
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                guard let chunkData = try handle.read(upToCount: size)
                    else { throw DataError.truncated }
                return chunkData
            } else {
                // Technically, this can throw NSException, but since it is ObjC exception we cannot handle it in Swift.
                return handle.readData(ofLength: size)
            }
        #endif
    }

}
