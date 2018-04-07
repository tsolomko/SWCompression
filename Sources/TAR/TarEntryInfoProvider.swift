// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

// While it is tempting to make Provider conform to `IteratorProtocol` and `Sequence` protocols, it is in fact
// impossible to do so, since `TarEntryInfo.init(...)` is throwing and `IteratorProtocol.next()` cannot be throwing.
// TODO: Struct or class?
struct TarEntryInfoProvider {

    private let byteReader: ByteReader
    private var lastGlobalExtendedHeader: TarExtendedHeader?
    private var lastLocalExtendedHeader: TarExtendedHeader?
    private var longLinkName: String?
    private var longName: String?

    init(_ data: Data) {
        self.byteReader = ByteReader(data: data)
    }

    mutating func next() throws -> TarEntryInfo? {
        // TODO: Check, if bytes left is >= 1024.
        guard byteReader.data[byteReader.offset..<byteReader.offset + 1024] != Data(count: 1024)
            else { return nil }

        let info = try TarEntryInfo(byteReader, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                    longName, longLinkName)
        let dataStartIndex = info.blockStartIndex + 512

        if let specialEntryType = info.specialEntryType {
            switch specialEntryType {
            case .globalExtendedHeader:
                let dataEndIndex = dataStartIndex + info.size!
                lastGlobalExtendedHeader = try TarExtendedHeader(byteReader.data[dataStartIndex..<dataEndIndex])
            case .localExtendedHeader:
                let dataEndIndex = dataStartIndex + info.size!
                lastLocalExtendedHeader = try TarExtendedHeader(byteReader.data[dataStartIndex..<dataEndIndex])
            case .longLinkName:
                byteReader.offset = dataStartIndex
                longLinkName = try byteReader.nullEndedAsciiString(cutoff: info.size!)
            case .longName:
                byteReader.offset = dataStartIndex
                longName = try byteReader.nullEndedAsciiString(cutoff: info.size!)
            }
            byteReader.offset = dataStartIndex + info.size!.roundTo512()
        } else {
            // Skip file data.
            byteReader.offset = dataStartIndex + info.size!.roundTo512()
            lastLocalExtendedHeader = nil
            longName = nil
            longLinkName = nil
        }
        return info
    }

}
