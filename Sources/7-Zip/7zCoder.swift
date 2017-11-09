// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipCoder {

    /// Possible coder IDs.
    struct ID {
        static let copy: [UInt8] = [0x00]
        /// Shouldn't be used, added for compatibility, `ID.copy` should be used instead.
        static let zipCopy: [UInt8] = [0x04, 0x01, 0x00]
        static let deflate: [UInt8] = [0x04, 0x01, 0x08]
        /// Shouldn't be used, added for compatibility, `ID.bzip2` should be used instead.
        static let zipBzip2: [UInt8] = [0x04, 0x01, 0x0C]
        static let bzip2: [UInt8] = [0x04, 0x02, 0x02]
        static let lzma2: [UInt8] = [0x21]
        static let lzma: [UInt8] = [0x03, 0x01, 0x01]
    }

    let idSize: Int
    let isComplex: Bool
    let hasAttributes: Bool

    let id: [UInt8]
    let compressionMethod: CompressionMethod

    let numInStreams: Int
    let numOutStreams: Int

    var propertiesSize: Int?
    var properties: [UInt8]?

    init(_ bitReader: BitReader) throws {
        let flags = bitReader.byte()
        guard flags & 0xC0 == 0
            else { throw SevenZipError.internalStructureError }
        idSize = (flags & 0x0F).toInt()
        isComplex = flags & 0x10 != 0
        hasAttributes = flags & 0x20 != 0

        let id = bitReader.bytes(count: idSize)
        self.id = id
        compressionMethod = CompressionMethod(id)

        numInStreams = isComplex ? bitReader.szMbd() : 1
        numOutStreams = isComplex ? bitReader.szMbd() : 1

        if hasAttributes {
            propertiesSize = bitReader.szMbd()
            properties = bitReader.bytes(count: propertiesSize!)
        }
    }

}
