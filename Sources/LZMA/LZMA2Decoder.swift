// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class LZMA2Decoder {

    private let pointerData: DataWithPointer
    private let decoder: LZMADecoder

    var out: [UInt8] {
        return self.decoder.out
    }

    init(_ pointerData: DataWithPointer) throws {
        self.pointerData = pointerData
        self.decoder = try LZMADecoder(pointerData)
    }

    func setDictionarySize(_ byte: UInt8) throws {
        let bits = byte & 0x3F
        guard byte & 0xC0 == 0
            else { throw LZMA2Error.wrongProperties }
        guard bits < 40
            else { throw LZMA2Error.wrongDictionarySize }

        var dictSize: UInt32 = 0
        if bits == 40 {
            dictSize = UInt32.max
        } else {
            dictSize = UInt32(2 | (bits.toInt() & 1))
            dictSize <<= UInt32(bits.toInt() / 2 + 11)
        }

        self.decoder.dictionarySize = Int(dictSize)
    }

    /// Main LZMA2 decoder function.
    func decode() throws {
        mainLoop: while true {
            let controlByte = pointerData.byte()
            switch controlByte {
            case 0:
                break mainLoop
            case 1:
                self.decoder.resetDictionary()
                self.decodeUncompressed()
            case 2:
                self.decodeUncompressed()
            case 3...0x7F:
                throw LZMA2Error.wrongControlByte
            case 0x80...0xFF:
                try self.dispatch(controlByte)
            default:
                fatalError("Incorrect control byte.") // This statement is never executed.
            }
        }
    }

    /// Function which dispatches LZMA2 decoding process based on `controlByte`.
    private func dispatch(_ controlByte: UInt8) throws {
        let uncompressedSizeBits = controlByte & 0x1F
        let reset = (controlByte & 0x60) >> 5
        let unpackSize = (uncompressedSizeBits.toInt() << 16) +
            self.pointerData.byte().toInt() << 8 + self.pointerData.byte().toInt() + 1
        let compressedSize = self.pointerData.byte().toInt() << 8 + self.pointerData.byte().toInt() + 1
        var dataStartIndex = pointerData.index
        switch reset {
        case 0:
            break
        case 1:
            self.decoder.resetStateAndDecoders()
        case 2:
            try self.decoder.setProperties(pointerData.byte())
            self.decoder.resetStateAndDecoders()
            dataStartIndex += 1
        case 3:
            try self.decoder.setProperties(pointerData.byte())
            self.decoder.resetStateAndDecoders()
            dataStartIndex += 1
            self.decoder.resetDictionary()
        default:
            throw LZMA2Error.wrongReset
        }
        self.decoder.uncompressedSize = unpackSize
        let startCount = self.decoder.out.count
        try self.decoder.decode()
        guard unpackSize == self.decoder.out.count - startCount &&
            self.pointerData.index - dataStartIndex == compressedSize
            else { throw LZMA2Error.wrongSizes }
    }

    private func decodeUncompressed() {
        let dataSize = self.pointerData.byte().toInt() << 8 + self.pointerData.byte().toInt() + 1
        for _ in 0..<dataSize {
            self.decoder.put(pointerData.byte())
        }
    }

}

