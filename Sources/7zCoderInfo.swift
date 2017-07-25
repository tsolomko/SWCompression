// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipCoderInfo {

    let numFolders: Int

    let external: UInt8
    var folders = [SevenZipFolder]()
    var dataStreamIndex: Int?
    let unpackSizes: [Int]
    var digests = [UInt32?]()

    init(_ pointerData: DataWithPointer) throws {
        guard pointerData.byte() == 0x0B
            else { throw SevenZipError.wrongPropertyID }
        numFolders = pointerData.szMbd().multiByteInteger
        external = pointerData.byte()
        switch external {
        case 0:
            for _ in 0..<numFolders {
                folders.append(try SevenZipFolder(pointerData))
            }
        case 1:
            dataStreamIndex = pointerData.szMbd().multiByteInteger
        default:
            throw SevenZipError.wrongExternal
        }

        guard pointerData.byte() == 0x0C
            else { throw SevenZipError.wrongPropertyID }
        var sizes = [Int]()
        if external == 0 {
            for folder in folders {
                for _ in 0..<folder.numPackedStreams { // TODO: ???
                    sizes.append(pointerData.szMbd().multiByteInteger)
                }
            }
        }
        unpackSizes = sizes

        switch pointerData.byte() {
        case 0x0A:
            // TODO: Extract digests code.
            let allDefined = pointerData.byte()
            let definedBits: [UInt8]
            if allDefined == 0 {
                let bitReader = BitReader(data: pointerData.data, bitOrder: .reversed) // TODO: Bit order???
                bitReader.index = pointerData.index
                definedBits = bitReader.bits(count: numFolders)
                bitReader.skipUntilNextByte()
                pointerData.index = bitReader.index
            } else {
                definedBits = Array(repeating: 1, count: numFolders)
            }
            for bit in definedBits {
                if bit == 1 {
                    digests.append(pointerData.uint32())
                } else {
                    digests.append(nil)
                }
            }
            guard pointerData.byte() == 0x00
                else { throw SevenZipError.wrongPropertyID }
        case 0x00:
            break
        default:
            throw SevenZipError.wrongPropertyID
        }
    }
}
