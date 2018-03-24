// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import BitByteData

struct ExtendedTimestampExtraField: ZipExtraField {

    static let id: UInt16 = 0x5455

    let size: Int
    let location: ZipExtraFieldLocation

    var accessTimestamp: UInt32?
    var creationTimestamp: UInt32?
    var modificationTimestamp: UInt32?

    init(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        switch location {
        case .centralDirectory:
            let flags = byteReader.byte()
            if flags & 0x01 != 0 {
                self.modificationTimestamp = byteReader.uint32()
            }
        case .localHeader:
            let flags = byteReader.byte()
            if flags & 0x01 != 0 {
                self.modificationTimestamp = byteReader.uint32()
            }
            if flags & 0x02 != 0 {
                self.accessTimestamp = byteReader.uint32()
            }
            if flags & 0x04 != 0 {
                self.creationTimestamp = byteReader.uint32()
            }
        }
    }

}

struct NtfsExtraField: ZipExtraField {

    static let id: UInt16 = 0x000A

    let size: Int
    let location: ZipExtraFieldLocation

    let ntfsAtime: UInt64
    let ntfsCtime: UInt64
    let ntfsMtime: UInt64

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        byteReader.offset += 4 // Skip reserved bytes
        let tag = byteReader.uint16() // This attribute's tag
        byteReader.offset += 2 // Skip size of this attribute
        guard tag == 0x0001
            else { return nil }
        self.ntfsMtime = byteReader.uint64()
        self.ntfsAtime = byteReader.uint64()
        self.ntfsCtime = byteReader.uint64()
    }

}

struct InfoZipUnixExtraField: ZipExtraField {

    static let id: UInt16 = 0x7855

    let size: Int
    let location: ZipExtraFieldLocation

    let infoZipUid: UInt16
    let infoZipGid: UInt16

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        switch location {
        case .centralDirectory:
            return nil
        case .localHeader:
            self.infoZipUid = byteReader.uint16()
            self.infoZipGid = byteReader.uint16()
        }
    }

}

struct InfoZipNewUnixExtraField: ZipExtraField {

    static let id: UInt16 = 0x7875

    let size: Int
    let location: ZipExtraFieldLocation

    var infoZipNewUid: Int?
    var infoZipNewGid: Int?

    init?(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        guard byteReader.byte() == 1 // Version must be 1
            else { return nil }

        let uidSize = byteReader.byte().toInt()
        if uidSize > 8 {
            byteReader.offset += uidSize
        } else {
            var uid = 0
            for i in 0..<uidSize {
                let byte = byteReader.byte()
                uid |= byte.toInt() << (8 * i)
            }
            self.infoZipNewUid = uid
        }

        let gidSize = byteReader.byte().toInt()
        if gidSize > 8 {
            byteReader.offset += gidSize
        } else {
            var gid = 0
            for i in 0..<gidSize {
                let byte = byteReader.byte()
                gid |= byte.toInt() << (8 * i)
            }
            self.infoZipNewGid = gid
        }
    }

}
