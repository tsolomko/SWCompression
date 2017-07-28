// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipCoderInfo {

    let numFolders: Int

    let external: UInt8
    private(set) var folders = [SevenZipFolder]()

    init() {
        numFolders = 0
        external = 0
    }

    init(_ bitReader: BitReader) throws {
        var type = bitReader.byte()
        guard type == 0x0B else { throw SevenZipError.wrongPropertyID }

        numFolders = bitReader.szMbd()
        external = bitReader.byte()

        guard external == 0
            else { throw SevenZipError.externalNotSupported } // TODO: Do we support this?

        for _ in 0..<numFolders {
            folders.append(try SevenZipFolder(bitReader))
        }

        type = bitReader.byte()
        guard type == 0x0C else { throw SevenZipError.wrongPropertyID }

        for folder in folders {
            for _ in 0..<folder.totalOutputStreams {
                folder.unpackSizes.append(bitReader.szMbd())
            }
        }

        type = bitReader.byte()
    
        if type == 0x0A {
            let allDefined = bitReader.byte()
            let definedBits: [UInt8]
            if allDefined == 0 {
                definedBits = bitReader.bits(count: numFolders)
                bitReader.skipUntilNextByte()
            } else {
                definedBits = Array(repeating: 1, count: numFolders)
            }

            for i in 0..<numFolders {
                if definedBits[i] == 1 {
                    folders[i].crc = bitReader.uint32()
                }
            }
            
            type = bitReader.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }
}
