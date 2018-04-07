// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for work with TAR containers.
public class TarContainer: Container {

    public enum Format {
        case prePosix
        case ustar
        case gnu
        case pax
    }

    public static func formatOf(container data: Data) throws -> Format {
        // TAR container should be at least 512 bytes long (when it contains only one header).
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        var infoProvider = TarEntryInfoProvider(data)

        var specialMagicEncountered = false

        while let info = try infoProvider.next() {
            if info.specialEntryType == .globalExtendedHeader || info.specialEntryType == .localExtendedHeader {
                return .pax
            } else if info.specialEntryType == .longName || info.specialEntryType == .longLinkName {
                return .gnu
            } else if info.hasRecognizedMagic {
                specialMagicEncountered = true
            }
        }

        return specialMagicEncountered ? .ustar : .prePosix
    }

    /**
     Processes TAR container and returns an array of `TarEntry` with information and data for all entries.

     - Important: The order of entries is defined by TAR container and, particularly, by the creator of a given TAR
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

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

     - Important: The order of entries is defined by TAR container and, particularly, by the creator of a given TAR
     container. It is likely that directories will be encountered earlier than files stored in those directories, but no
     particular order is guaranteed.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntryInfo`.
     */
    public static func info(container data: Data) throws -> [TarEntryInfo] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        var infoProvider = TarEntryInfoProvider(data)
        var entries = [TarEntryInfo]()

        while let info = try infoProvider.next() {
            guard info.specialEntryType == nil
                else { continue }
            entries.append(info)
        }

        return entries
    }

}
