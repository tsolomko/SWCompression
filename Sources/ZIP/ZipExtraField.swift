// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import BitByteData

public protocol ZipExtraField {

    static var id: UInt16 { get }

    var location: ZipExtraFieldLocation { get }
    var size: Int { get }

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation)

}

extension ZipExtraField {

    public var id: UInt16 {
        return Self.id
    }

}

public enum ZipExtraFieldLocation {

    case centralDirectory
    case localHeader

}
