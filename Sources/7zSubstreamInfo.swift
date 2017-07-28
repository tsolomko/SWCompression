// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipSubstreamInfo {

    var numUnpackStreamsInFolders = [Int]()
    var unpackSizes = [Int]()
    var digests = [UInt32?]()

    init(_ pointerData: DataWithPointer, _ coderInfo: SevenZipCoderInfo) throws {
        var totalUnpackStreams = coderInfo.folders.count

        var type = pointerData.byte()

        if type == 0x0D {
            totalUnpackStreams = 0
            for folder in coderInfo.folders {
                let numStreams = pointerData.szMbd()
                folder.numUnpackSubstreams = numStreams
                totalUnpackStreams += numStreams
            }
            type = pointerData.byte()
        }

        for folder in coderInfo.folders {
            if folder.numUnpackSubstreams == 0 {
                continue
            }
            var sum = 0
            if type == 0x09 {
                for _ in 0..<folder.numUnpackSubstreams - 1 {
                    let size = pointerData.szMbd()
                    unpackSizes.append(size)
                    sum += size
                }
            }
            unpackSizes.append(folder.unpackSize() - sum)
        }
        if type == 0x09 {
            type = pointerData.byte()
        }

        var totalDigests = 0
        for folder in coderInfo.folders {
            if folder.numUnpackSubstreams != 1 || folder.crc == nil {
                totalDigests += folder.numUnpackSubstreams
            }
        }

        if type == 0x0A {
            let allDefined = pointerData.byte()
            let definedBits: [UInt8]
            if allDefined == 0 {
                let bitReader = BitReader(data: pointerData.data, bitOrder: .straight)
                bitReader.index = pointerData.index
                definedBits = bitReader.bits(count: totalDigests)
                bitReader.skipUntilNextByte()
                pointerData.index = bitReader.index
            } else {
                definedBits = Array(repeating: 1, count: totalDigests)
            }

            var missingCrcs = [UInt32?]()
            for i in 0..<totalDigests {
                if definedBits[i] == 1 {
                    missingCrcs.append(pointerData.uint32())
                } else {
                    missingCrcs.append(nil)
                }
            }

            for folder in coderInfo.folders {
                if folder.numUnpackSubstreams == 1 && folder.crc != nil {
                    digests.append(folder.crc)
                } else {
                    for i in 0..<folder.numUnpackSubstreams {
                        digests.append(missingCrcs[i])
                    }
                }

                type = pointerData.byte()
            }
        }

        if type != 0x00 {
            throw SevenZipError.wrongEnd
        }
    }

}
