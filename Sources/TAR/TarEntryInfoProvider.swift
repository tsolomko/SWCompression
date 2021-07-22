// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

// While it is tempting to make Provider conform to `IteratorProtocol` and `Sequence` protocols, it is in fact
// impossible to do so, since `TarEntryInfo.init(...)` is throwing and `IteratorProtocol.next()` cannot be throwing.
struct TarEntryInfoProvider {

    private let reader: LittleEndianByteReader
    private var lastGlobalExtendedHeader: TarExtendedHeader?
    private var lastLocalExtendedHeader: TarExtendedHeader?
    private var longLinkName: String?
    private var longName: String?

    init(_ data: Data) {
        self.reader = LittleEndianByteReader(data: data)
    }

    mutating func next() throws -> TarEntryInfo? {
        guard reader.bytesLeft >= 1024,
            reader.data[reader.offset..<reader.offset + 1024] != Data(count: 1024)
            else { return nil }

        let info = try TarEntryInfo(reader, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                    longName, longLinkName)
        let dataStartIndex = info.blockStartIndex + 512

        if let specialEntryType = info.specialEntryType {
            switch specialEntryType {
            case .globalExtendedHeader:
                let dataEndIndex = dataStartIndex + info.size!
                lastGlobalExtendedHeader = try TarExtendedHeader(reader.data[dataStartIndex..<dataEndIndex])
            case .sunExtendedHeader:
                fallthrough
            case .localExtendedHeader:
                let dataEndIndex = dataStartIndex + info.size!
                lastLocalExtendedHeader = try TarExtendedHeader(reader.data[dataStartIndex..<dataEndIndex])
            case .longLinkName:
                reader.offset = dataStartIndex
                longLinkName = reader.tarCString(maxLength: info.size!)
            case .longName:
                reader.offset = dataStartIndex
                longName = reader.tarCString(maxLength: info.size!)
            }
            reader.offset = dataStartIndex + info.size!.roundTo512()
        } else {
            // Skip file data.
            reader.offset = dataStartIndex + info.size!.roundTo512()
            lastLocalExtendedHeader = nil
            longName = nil
            longLinkName = nil
        }
        return info
    }

}
