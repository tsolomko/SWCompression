// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for work with TAR containers.
public class TarContainer: Container {

    /**
     Processes TAR container and returns an array of `TarEntry` with information and data for all entries.

     - Important: The order of entries is defined by TAR container and, particularly,
     by the creator of a given TAR container. It is likely that directories will be encountered earlier
     than files stored in those directories, but one SHOULD NOT rely on any particular order.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntry`.
     */
    public static func open(container data: Data) throws -> [TarEntry] {
        let infos = try info(container: data)
        var entries = [TarEntry]()

        for entryInfo in infos {
            if entryInfo.type == .directory {
                entries.append(TarEntry(entryInfo, nil))
            } else {
                let dataStartIndex = entryInfo.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + entryInfo.size!
                let entryData = data[dataStartIndex..<dataEndIndex]
                entries.append(TarEntry(entryInfo, entryData))
            }
        }

        return entries
    }

    /**
     Processes TAR container and returns an array of `TarEntryInfo` with information about entries in this container.

     - Important: The order of entries is defined by TAR container and, particularly,
     by the creator of a given TAR container. It is likely that directories will be encountered earlier
     than files stored in those directories, but one SHOULD NOT rely on any particular order.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntryInfo`.
     */
    public static func info(container data: Data) throws -> [TarEntryInfo] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        let byteReader = ByteReader(data: data)

        var entries = [TarEntryInfo]()

        var lastGlobalExtendedHeader: TarExtendedHeader?
        var lastLocalExtendedHeader: TarExtendedHeader?
        var longLinkName: String?
        var longName: String?

        // Container ends with two zero-filled records.
        while byteReader.data[byteReader.offset..<byteReader.offset + 1024] != Data(count: 1024) {
            let info = try TarEntryInfo(byteReader, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                        longName, longLinkName)

            if info.isGlobalExtendedHeader {
                let dataStartIndex = info.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + info.size!

                lastGlobalExtendedHeader = try TarExtendedHeader(data[dataStartIndex..<dataEndIndex])
                byteReader.offset = dataEndIndex - info.size! + info.size!.roundTo512()
            } else if info.isLocalExtendedHeader {
                let dataStartIndex = info.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + info.size!

                lastLocalExtendedHeader = try TarExtendedHeader(data[dataStartIndex..<dataEndIndex])
                byteReader.offset = dataEndIndex - info.size! + info.size!.roundTo512()
            } else if info.isLongLinkName {
                let dataStartIndex = info.blockStartIndex + 512
                byteReader.offset = dataStartIndex

                longLinkName = try byteReader.nullEndedAsciiString(cutoff: info.size!)
                byteReader.offset = dataStartIndex + info.size!.roundTo512()
            } else if info.isLongName {
                let dataStartIndex = info.blockStartIndex + 512
                byteReader.offset = dataStartIndex

                longName = try byteReader.nullEndedAsciiString(cutoff: info.size!)
                byteReader.offset = dataStartIndex + info.size!.roundTo512()
            } else {
                // Skip file data.
                byteReader.offset = info.blockStartIndex + 512 + info.size!.roundTo512()
                entries.append(info)
                lastLocalExtendedHeader = nil
                longName = nil
                longLinkName = nil
            }
        }

        return entries
    }

}
