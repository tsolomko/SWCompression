// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipFolder {

    struct BindPair {

        let inIndex: Int
        let outIndex: Int

        init(_ pointerData: DataWithPointer) throws {
            inIndex = pointerData.szMbd().multiByteInteger
            outIndex = pointerData.szMbd().multiByteInteger
        }

    }

    let numCodecs: Int
    let codecs: [SevenZipCodec]

    let numBindPairs: Int
    let bindPairs: [BindPair]

    let numPackedStreams: Int

    let packedIndices: [Int]

    init(_ pointerData: DataWithPointer) throws {
        numCodecs = pointerData.szMbd().multiByteInteger
        var codecs = [SevenZipCodec]()
        var outStreamsTotal = 0
        var inStreamsTotal = 0
        for _ in 0..<numCodecs {
            let codec = try SevenZipCodec(pointerData)
            codecs.append(codec)
            outStreamsTotal += codec.numOutStreams
            inStreamsTotal += codec.numInStreams
        }
        self.codecs = codecs
        numBindPairs = outStreamsTotal - 1

        var pairs = [BindPair]()
        if numBindPairs > 0 {
            for _ in 0..<numBindPairs {
                pairs.append(try BindPair(pointerData))
            }
        }
        bindPairs = pairs

        numPackedStreams = inStreamsTotal - numBindPairs
        var indices = [Int]()
        if numPackedStreams > 1 {
            for _ in 0..<numPackedStreams {
                indices.append(pointerData.szMbd().multiByteInteger)
            }
        }
        packedIndices = indices
    }
}
