// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides functions for work with TAR containers.
public class TarContainer: Container {

    /**
     Represents the "format" of a TAR container: a minimal set of extensions to basic TAR format required to
     successfully read a particular container.
     */
    public enum Format {
        /// Pre POSIX format (aka "basic TAR format").
        case prePosix
        /// "UStar" format introduced by POSIX IEEE P1003.1 standard.
        case ustar
        /// "UStar"-like format with GNU extensions (e.g. special container entries for long file and link names).
        case gnu
        /// "PAX" format introduced by POSIX.1-2001 standard, a set of extensions to "UStar" format.
        case pax
    }

    /**
     Processes TAR container and returns its "format": a minimal set of extensions to basic TAR format required to
     successfully read this container.

     - Parameter container: TAR container's data.

     - Throws: `TarError`, which may indicate that either container is damaged or it might not be TAR container at all.

     - SeeAlso: `TarContainer.Format`
     */
    public static func formatOf(container data: Data) throws -> Format {
        // TAR container should be at least 512 bytes long (when it contains only one header).
        guard data.count >= 512
            else { throw TarError.tooSmallFileIsPassed }

        var infoProvider = TarEntryInfoProvider(data)

        var ustarEncountered = false

        while let info = try infoProvider.next() {
            if info.specialEntryType == .globalExtendedHeader || info.specialEntryType == .localExtendedHeader {
                return .pax
            } else if info.specialEntryType == .longName || info.specialEntryType == .longLinkName {
                return .gnu
            } else {
                switch info.format {
                case .pax:
                    return .pax
                case .gnu:
                    return .gnu
                case .ustar:
                    ustarEncountered = true
                case .prePosix:
                    break
                }
            }
        }

        return ustarEncountered ? .ustar : .prePosix
    }

    /**
     Creates a new TAR container with `entries` as its content and generates its `Data`.

     - Parameter entries: TAR entries to store in the container.

     - Throws: `TarCreateError.utf8NonEncodable` which indicates that one of the `TarEntryInfo`'s string properties
     (such as `name`) cannot be encoded with UTF-8 encoding.

     - SeeAlso: `TarEntryInfo` properties documenation to see how their values are connected with the specific TAR
     format used during container creation.
     */
    public static func create(from entries: [TarEntry]) -> Data {
        create(from: entries, force: .pax)
    }

    public static func create(from entries: [TarEntry], force format: TarContainer.Format)  -> Data {
        // The general strategy is as follows. For each entry we:
        //  1. Create special entries if required by the entry's info and if supported by the format.
        //  2. For each special entry we create TarHeader.
        //  3. For each TarHeader we generate binary data, and the append it with the content of the special entry to
        //     the output.
        //  4. Perform the previous two steps for the entry itself.
        // Every time we append something to the output we also make sure that the data is padded to 512 byte-long blocks.

        // TODO: Add counters for special entries. Check if overflow.
        var out = Data()
        for entry in entries {
            if format == .gnu {
                if entry.info.name.utf8.count > 100 {
                    let nameData = Data(entry.info.name.utf8)
                    let longNameHeader = TarHeader(specialName: "SWC_LongName", specialType: .longName,
                                                   size: nameData.count, uid: entry.info.ownerID,
                                                   gid: entry.info.groupID)
                    out.append(longNameHeader.generateContainerData(.gnu))
                    assert(out.count % 512 == 0)
                    out.appendAsTarBlock(nameData)
                }

                if entry.info.linkName.utf8.count > 100 {
                    let linkNameData = Data(entry.info.linkName.utf8)
                    let longLinkNameHeader = TarHeader(specialName: "SWC_LongLinkName", specialType: .longLinkName,
                                                       size: linkNameData.count, uid: entry.info.ownerID,
                                                       gid: entry.info.groupID)
                    out.append(longLinkNameHeader.generateContainerData(.gnu))
                    assert(out.count % 512 == 0)
                    out.appendAsTarBlock(linkNameData)
                }
            } else if format == .pax {
                let extHeader = TarExtendedHeader(entry.info)
                let extHeaderData = extHeader.generateContainerData()
                if !extHeaderData.isEmpty {
                    let extHeaderHeader = TarHeader(specialName: "SWC_LocalPaxHeader", specialType: .localExtendedHeader,
                                                    size: extHeaderData.count, uid: entry.info.ownerID,
                                                    gid: entry.info.groupID)
                    out.append(extHeaderHeader.generateContainerData(.pax))
                    assert(out.count % 512 == 0)
                    out.appendAsTarBlock(extHeaderData)
                }
            }

            let header = TarHeader(entry.info)
            out.append(header.generateContainerData(format))
            assert(out.count % 512 == 0)
            if let data = entry.data {
                out.appendAsTarBlock(data)
            }
        }
        // Two 512-byte blocks consisting of zeros as an EOF marker.
        out.append(Data(count: 1024))
        return out
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
                var entry = TarEntry(info: entryInfo, data: nil)
                entry.info.size = 0
                entries.append(entry)
            } else {
                let dataStartIndex = entryInfo.blockStartIndex + 512
                let dataEndIndex = dataStartIndex + entryInfo.size!
                // Verify that data is not truncated.
                // The data.startIndex inequality is strict since by this point at least one header (i.e. 512 bytes)
                // has been processed. The data.endIndex inequality is strict since there must be a 1024 bytes-long EOF
                // marker block which isn't included into any entry.
                guard dataStartIndex > data.startIndex && dataEndIndex < data.endIndex
                    else { throw TarError.wrongField }
                let entryData = data.subdata(in: dataStartIndex..<dataEndIndex)
                entries.append(TarEntry(info: entryInfo, data: entryData))
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
        // TAR container should be at least 512 bytes long (when it contains only one header).
        guard data.count >= 512
            else { throw TarError.tooSmallFileIsPassed }

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
