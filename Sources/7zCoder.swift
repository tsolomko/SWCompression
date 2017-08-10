// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipCoder {

    /// Possible coder IDs.
    struct ID {
    // TODO: Left comments column indicates whether coder has been implemented or not (I/NI) and tested (T/NT).
    /*  I/T  */static let copy: [UInt8] = [0x00]
        /// Shouldn't be used, added for compatibility, `ID.copy` should be used instead.
    /*  I/T  */static let zipCopy: [UInt8] = [0x04, 0x01, 0x00]
    /*  I/T  */static let deflate: [UInt8] = [0x04, 0x01, 0x08]
        /// Shouldn't be used, added for compatibility, `ID.bzip2` should be used instead.
    /*  I/T  */static let zipBzip2: [UInt8] = [0x04, 0x01, 0x0C]
    /* NI/NT */static let zipLzma: [UInt8] = [0x04, 0x01, 0x0E]
        /// For some reason, this method is specified in ZIP section of Methods.txt.
    /* NI/NT */static let xz: [UInt8] = [0x04, 0x01, 0x5F]
    /*  I/T  */static let bzip2: [UInt8] = [0x04, 0x02, 0x02]
    /*  I/T  */static let lzma2: [UInt8] = [0x21]
    /*  I/T  */static let lzma: [UInt8] = [0x03, 0x01, 0x01]
    }

    let idSize: Int
    let isComplex: Bool
    let hasAttributes: Bool

    let id: [UInt8]

    let numInStreams: Int
    let numOutStreams: Int

    var propertiesSize: Int?
    var properties: [UInt8]?

    init(_ bitReader: BitReader) throws {
        let flags = bitReader.byte()
        guard flags & 0xC0 == 0
            else { throw SevenZipError.reservedCodecFlags }
        idSize = (flags & 0x0F).toInt()
        isComplex = flags & 0x10 != 0
        hasAttributes = flags & 0x20 != 0

        guard flags & 0x80 == 0 else { throw SevenZipError.altMethodsNotSupported }

        id = bitReader.bytes(count: idSize)

        numInStreams = isComplex ? bitReader.szMbd() : 1
        numOutStreams = isComplex ? bitReader.szMbd() : 1

        if hasAttributes {
            propertiesSize = bitReader.szMbd()
            properties = bitReader.bytes(count: propertiesSize!)
        }
    }

}

extension SevenZipCoder: Equatable {

    static func == (lhs: SevenZipCoder, rhs: SevenZipCoder) -> Bool {
        let propertiesEqual: Bool
        if lhs.properties == nil && rhs.properties == nil {
            propertiesEqual = true
        } else if lhs.properties != nil && rhs.properties != nil {
            propertiesEqual = lhs.properties! == rhs.properties!
        } else {
            propertiesEqual = false
        }
        return lhs.id == rhs.id && lhs.numInStreams == rhs.numInStreams &&
            lhs.numOutStreams == rhs.numOutStreams && propertiesEqual
    }

}
