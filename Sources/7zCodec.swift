// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipCodec {

    let idSize: Int
    let isComplex: Bool
    let attributesExist: Bool

    let id: [UInt8]

    let numInStreams: Int
    let numOutStreams: Int

    var propertiesSize: Int?
    var properties: [UInt8]?

    init(_ pointerData: DataWithPointer) throws {
        let flags = pointerData.byte()
        guard flags & 0xC0 == 0
            else { throw SevenZipError.reservedCodecFlags }
        idSize = (flags & 0xF).toInt()
        isComplex = flags & 0x10 != 0
        attributesExist = flags & 0x20 != 0

        id = pointerData.bytes(count: idSize)

        // TODO: Introduce typealias for SevenZipError.multiByteIntegerError.
        numInStreams = isComplex ? try pointerData
            .multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger : 1
        numOutStreams = isComplex ? try pointerData
            .multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger : 1

        if attributesExist {
            propertiesSize = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
            properties = pointerData.bytes(count: propertiesSize!)
        }
    }
}
