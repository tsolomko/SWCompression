// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides open function for TAR containers.
public class TarContainer {

    /**
     Processes TAR container and returns an array of `ContainerEntry` (which are actually `TarEntry`).

     - Important: The order of entries is defined by TAR container and,
     particularly, by the creator of a given TAR container.
     It is likely that directories will be encountered earlier than files stored in those directories,
     but one SHOULD NOT rely on any particular order.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - Returns: Array of `TarEntry` as an array of `ContainerEntry`.
     */
    public static func open(container data: Data) throws -> [TarEntry] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        var output = [TarEntry]()

        var lastGlobalExtendedHeader: String?
        var lastLocalExtendedHeader: String?
        var longLinkName: String?
        var longName: String?

        // Container ends with two zero-filled records.
        // TODO: Add better check and error throw.
        while true {
            if pointerData.bytes(count: 1024) == Array(repeating: 0, count: 1024) {
                break
            } else {
                pointerData.index -= 1024
            }
            pointerData.index += 156
            let fileTypeIndicator = String(Character(UnicodeScalar(pointerData.byte())))
            if fileTypeIndicator == "K" || fileTypeIndicator == "L" {
                pointerData.index -= 33

                guard let octalSize = Int(try pointerData.nullSpaceEndedAsciiString(cutoff: 12))
                    else { throw TarError.fieldIsNotNumber }
                let size = octalSize.octalToDecimal()
                pointerData.index += 376

                let dataStartIndex = pointerData.index
                let longPath = try pointerData.nullEndedAsciiString(cutoff: size)

                if fileTypeIndicator == "K" {
                    longLinkName = longPath
                } else {
                    longName = longPath
                }
                pointerData.index = dataStartIndex
                pointerData.index += size.roundTo512()
                continue
            }
            pointerData.index -= 157

            let entry = try TarEntry(pointerData, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                     longName, longLinkName)
            switch entry.type {
            case .globalExtendedHeader:
                lastGlobalExtendedHeader = String(data: entry.data(), encoding: .utf8)
            case .localExtendedHeader:
                lastLocalExtendedHeader = String(data: entry.data(), encoding: .utf8)
            default:
                output.append(entry)
                lastLocalExtendedHeader = nil
                longName = nil
                longLinkName = nil
            }
        }

        return output
    }

}
