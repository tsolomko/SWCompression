// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipFolder {

    struct BindPair {

        let inIndex: Int
        let outIndex: Int

        init(_ pointerData: DataWithPointer) throws {
            inIndex = pointerData.szMbd().multiByteInteger
            outIndex = pointerData.szMbd().multiByteInteger
        }

    }

    let numCoders: Int
    private(set) var coders = [SevenZipCoder]()

    let numBindPairs: Int
    private(set) var bindPairs = [BindPair]()

    let numPackedStreams: Int
    private(set) var packedStreams = [Int]()

    private(set) var totalOutputStreams = 0
    private(set) var totalInputStreams = 0

    // These properties are stored in CoderInfo.
    var crc: UInt32?
    var unpackSizes = [Int]()

    // This property is stored in SubstreamInfo.
    var numUnpackSubstreams = 1

    init(_ pointerData: DataWithPointer) throws {
        numCoders = pointerData.szMbd().multiByteInteger
        for _ in 0..<numCoders {
            let coder = try SevenZipCoder(pointerData)
            coders.append(coder)
            totalOutputStreams += coder.numOutStreams
            totalInputStreams += coder.numInStreams
        }

        guard totalOutputStreams != 0 else { throw SevenZipError.wrongStreamsNumber }

        numBindPairs = totalOutputStreams - 1
        if numBindPairs > 0 {
            for _ in 0..<numBindPairs {
                bindPairs.append(try BindPair(pointerData))
            }
        }

        guard totalInputStreams >= numBindPairs else { throw SevenZipError.wrongStreamsNumber }

        numPackedStreams = totalInputStreams - numBindPairs
        packedStreams = Array(repeating: 0, count: numPackedStreams)
        if numPackedStreams == 1 {
            var i = 0
            while i < totalInputStreams {
                if self.bindPairForInStream(i) < 0 {
                    break
                }
                i += 1
            }
            if i == totalInputStreams {
                throw SevenZipError.wrongStreamsNumber
            }
            packedStreams[0] = i
        } else {
            for i in 0..<numPackedStreams {
                packedStreams[i] = pointerData.szMbd().multiByteInteger
            }
        }
    }

    func orderedCoders() -> [SevenZipCoder] {
        var result = [SevenZipCoder]()
        var current = 0
        while current != -1 {
            result.append(coders[current])
            let pair = bindPairForOutStream(current)
            current = pair != -1 ? bindPairs[pair].inIndex : -1
        }
        return result
    }

    func bindPairForInStream(_ index: Int) -> Int {
        for i in 0..<bindPairs.count {
            if bindPairs[i].inIndex == index {
                return i
            }
        }
        return -1
    }

    func bindPairForOutStream(_ index: Int) -> Int {
        for i in 0..<bindPairs.count {
            if bindPairs[i].outIndex == index {
                return i
            }
        }
        return -1
    }

    func unpackSize() -> Int {
         if (totalOutputStreams == 0) {
             return 0
         }
        for i in stride(from: totalOutputStreams - 1, through: 0, by: -1) {
             if bindPairForOutStream(i) < 0 {
                 return unpackSizes[i]
             }
         }
         return 0
    }

}
