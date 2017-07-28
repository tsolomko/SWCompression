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

    init(_ pointerData: DataWithPointer) throws {
        var type = pointerData.byte()
        guard type == 0x0B else { throw SevenZipError.wrongPropertyID }

        numFolders = pointerData.szMbd()
        external = pointerData.byte()

        guard external == 0
            else { throw SevenZipError.externalNotSupported } // TODO: Do we support this?

        for _ in 0..<numFolders {
            folders.append(try SevenZipFolder(pointerData))
        }

        type = pointerData.byte()
        guard type == 0x0C else { throw SevenZipError.wrongPropertyID }

        for folder in folders {
            for _ in 0..<folder.totalOutputStreams {
                folder.unpackSizes.append(pointerData.szMbd())
            }
        }

        type = pointerData.byte()
    
        if type == 0x0A {
            let allDefined = pointerData.byte()
            let definedBits: [UInt8]
            if allDefined == 0 {
                let bitReader = BitReader(data: pointerData.data, bitOrder: .straight)
                bitReader.index = pointerData.index
                definedBits = bitReader.bits(count: numFolders)
                bitReader.skipUntilNextByte()
                pointerData.index = bitReader.index
            } else {
                definedBits = Array(repeating: 1, count: numFolders)
            }
            for i in 0..<numFolders {
                if definedBits[i] == 1 {
                    folders[i].crc = pointerData.uint32()
                }
            }
            type = pointerData.byte()
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }
}
