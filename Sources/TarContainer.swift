// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides open function for TAR containers.
public class TarContainer: Container {

    /**
     Processes TAR container and returns an array of `ContainerEntries` (which are actually `TarEntries`).

     - Important: The order of entries is defined by TAR container and,
     particularly, by a creator of a given TAR container.
     It is likely that directories will be encountered earlier than files stored in those directories,
     but one SHOULD NOT rely on any particular order.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntry` as an array of `ContainerEntry`.
     */
    public static func open(container data: Data) throws -> [ContainerEntry] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        var output = [TarEntry]()

        var lastGlobalExtendedHeader: String?
        var lastLocalExtendedHeader: String?

        // Container ends with two zero-filled records.
        // TODO: Add better check and error throw.
        while true {
            if pointerData.alignedBytes(count: 1024) == Array(repeating: 0, count: 1024) {
                break
            } else {
                pointerData.index -= 1024
            }
            let entry = try TarEntry(&pointerData, lastGlobalExtendedHeader, lastLocalExtendedHeader)
            switch entry.type {
            case .globalExtendedHeader:
                lastGlobalExtendedHeader = String(data: entry.data(), encoding: .utf8)
            case .localExtendedHeader:
                lastLocalExtendedHeader = String(data: entry.data(), encoding: .utf8)
            default:
                output.append(entry)
                lastLocalExtendedHeader = nil
            }
        }

        return output
    }

}
