// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public struct TarWriter {

    private let format: TarContainer.Format
    private let handle: FileHandle
    private var longNameCounter: UInt
    private var longLinkNameCounter: UInt
    private var localPaxHeaderCounter: UInt

    public init(fileHandle: FileHandle, force format: TarContainer.Format = .pax) {
        self.handle = fileHandle
        self.format = format
        self.longNameCounter = 0
        self.longLinkNameCounter = 0
        self.localPaxHeaderCounter = 0
    }

    public mutating func append(_ entry: TarEntry) throws {
        var out = Data()
        if format == .gnu {
            if entry.info.name.utf8.count > 100 {
                let nameData = Data(entry.info.name.utf8)
                let longNameHeader = TarHeader(specialName: "SWC_LongName_\(longNameCounter)",
                                               specialType: .longName, size: nameData.count,
                                               uid: entry.info.ownerID, gid: entry.info.groupID)
                out.append(longNameHeader.generateContainerData(.gnu))
                assert(out.count % 512 == 0)
                out.appendAsTarBlock(nameData)
                longNameCounter &+= 1
            }

            if entry.info.linkName.utf8.count > 100 {
                let linkNameData = Data(entry.info.linkName.utf8)
                let longLinkNameHeader = TarHeader(specialName: "SWC_LongLinkName_\(longLinkNameCounter)",
                                                   specialType: .longLinkName, size: linkNameData.count,
                                                   uid: entry.info.ownerID, gid: entry.info.groupID)
                out.append(longLinkNameHeader.generateContainerData(.gnu))
                assert(out.count % 512 == 0)
                out.appendAsTarBlock(linkNameData)
                longLinkNameCounter &+= 1
            }
        } else if format == .pax {
            let extHeader = TarExtendedHeader(entry.info)
            let extHeaderData = extHeader.generateContainerData()
            if !extHeaderData.isEmpty {
                let extHeaderHeader = TarHeader(specialName: "SWC_LocalPaxHeader_\(localPaxHeaderCounter)",
                                                specialType: .localExtendedHeader, size: extHeaderData.count,
                                                uid: entry.info.ownerID, gid: entry.info.groupID)
                out.append(extHeaderHeader.generateContainerData(.pax))
                assert(out.count % 512 == 0)
                out.appendAsTarBlock(extHeaderData)
                localPaxHeaderCounter &+= 1
            }
        }

        let header = TarHeader(entry.info)
        out.append(header.generateContainerData(format))
        assert(out.count % 512 == 0)
        try write(out)
        if let data = entry.data {
            try write(data)
            let paddingSize = data.count.roundTo512() - data.count
            try write(Data(count: paddingSize))
        }
    }

    public func finalize() throws {
        // First, we append two 512-byte blocks consisting of zeros as an EOF marker.
        try write(Data(count: 1024))
        // The synchronization is performed by the write(_:) function automatically.
    }

    private func write(_ data: Data) throws {
        #if compiler(<5.2)
            handle.write(data)
            handle.synchronizeFile()
        #else
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                try handle.write(contentsOf: data)
                try handle.synchronize()
            } else {
                handle.write(data)
                handle.synchronizeFile()
            }
        #endif
    }

}
