// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class ByteReader {

    let size: Int
    let data: Data
    var offset: Int

    var isAtTheEnd: Bool {
        return self.data.endIndex == self.offset
    }

    init(data: Data) {
        self.size = data.count
        self.data = data
        self.offset = data.startIndex
    }

    func byte() -> UInt8 {
        self.offset += 1
        return self.data[self.offset - 1]
    }

    func bytes(count: Int) -> [UInt8] {
        let result = self.data[self.offset..<self.offset + count].toArray(type: UInt8.self, count: count)
        self.offset += count
        return result
    }

    func uint64() -> UInt64 {
        let result = self.data[self.offset..<self.offset + 8].to(type: UInt64.self)
        self.offset += 8
        return result
    }

    func uint32() -> UInt32 {
        let result = self.data[self.offset..<self.offset + 4].to(type: UInt32.self)
        self.offset += 4
        return result
    }

    func uint16() -> UInt16 {
        let result = self.data[self.offset..<self.offset + 2].to(type: UInt16.self)
        self.offset += 2
        return result
    }

}
