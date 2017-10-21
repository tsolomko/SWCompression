// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides open function for TAR containers.
public class TarContainer: Container {

    /**
     Processes TAR container and returns an array of `TarEntry`.

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

        var lastGlobalExtendedHeader: TarExtendedHeader?
        var lastLocalExtendedHeader: TarExtendedHeader?
        var longLinkName: String?
        var longName: String?

        // Container ends with two zero-filled records.
        while pointerData.data[pointerData.index..<pointerData.index + 1024] != Data(count: 1024) {
            let info = try TarEntryInfo(pointerData, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                        longName, longLinkName)

            // File data
            let dataStartIndex = info.blockStartIndex + 512
            let dataEndIndex = dataStartIndex + info.size!
            let entryData = data[dataStartIndex..<dataEndIndex]
            pointerData.index = dataEndIndex - info.size! + info.size!.roundTo512()

            let entry = TarEntry(info, entryData)

            if info.isGlobalExtendedHeader {
                lastGlobalExtendedHeader = try TarExtendedHeader(entry.data)
            } else if info.isLocalExtendedHeader {
                lastLocalExtendedHeader = try TarExtendedHeader(entry.data)
            } else if info.isLongLinkName {
                let dataStartIndex = info.blockStartIndex + 512
                pointerData.index = dataStartIndex

                longLinkName = try pointerData.nullEndedAsciiString(cutoff: info.size!)
                pointerData.index = dataStartIndex + info.size!.roundTo512()
            } else if info.isLongName {
                let dataStartIndex = info.blockStartIndex + 512
                pointerData.index = dataStartIndex

                longName = try pointerData.nullEndedAsciiString(cutoff: info.size!)
                pointerData.index = dataStartIndex + info.size!.roundTo512()
            } else {
                output.append(entry)
                lastLocalExtendedHeader = nil
                longName = nil
                longLinkName = nil
            }
        }

        return output
    }

    public static func info(container data: Data) throws -> [TarEntryInfo] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }
        
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)
        
        var output = [TarEntryInfo]()
        
        var lastGlobalExtendedHeader: TarExtendedHeader?
        var lastLocalExtendedHeader: TarExtendedHeader?
        var longLinkName: String?
        var longName: String?

        // TODO: First, populate infos, then get data in second loop.
        // Container ends with two zero-filled records.
        while pointerData.data[pointerData.index..<pointerData.index + 1024] != Data(count: 1024) {            
            let info = try TarEntryInfo(pointerData, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                        longName, longLinkName)
            
            if info.isGlobalExtendedHeader {
                let dataStartIndex = info.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + info.size!

                lastGlobalExtendedHeader = try TarExtendedHeader(data[dataStartIndex..<dataEndIndex])
                pointerData.index = dataEndIndex - info.size! + info.size!.roundTo512()
            } else if info.isLocalExtendedHeader {
                let dataStartIndex = info.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + info.size!

                lastLocalExtendedHeader = try TarExtendedHeader(data[dataStartIndex..<dataEndIndex])
                pointerData.index = dataEndIndex - info.size! + info.size!.roundTo512()
            } else if info.isLongLinkName {
                let dataStartIndex = info.blockStartIndex + 512
                pointerData.index = dataStartIndex

                longLinkName = try pointerData.nullEndedAsciiString(cutoff: info.size!)
                pointerData.index = dataStartIndex + info.size!.roundTo512()
            } else if info.isLongName {
                let dataStartIndex = info.blockStartIndex + 512
                pointerData.index = dataStartIndex

                longName = try pointerData.nullEndedAsciiString(cutoff: info.size!)
                pointerData.index = dataStartIndex + info.size!.roundTo512()
            } else {
                // Skip file data.
                pointerData.index = info.blockStartIndex + 512 + info.size!.roundTo512()
                output.append(info)
                lastLocalExtendedHeader = nil
                longName = nil
                longLinkName = nil
            }
        }
        
        return output
    }

}
