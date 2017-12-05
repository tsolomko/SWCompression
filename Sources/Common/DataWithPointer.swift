// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class DataWithPointer {

    let size: Int
    let data: Data
    var index: Int

    var isAtTheEnd: Bool {
        return self.data.endIndex == self.index
    }

    init(data: Data) {
        self.size = data.count
        self.data = data
        self.index = data.startIndex
    }

    func byte() -> UInt8 {
        self.index += 1
        return self.data[self.index - 1]
    }

    func bytes(count: Int) -> [UInt8] {
        let result = self.data[self.index..<self.index + count].toArray(type: UInt8.self, count: count)
        self.index += count
        return result
    }

    func uint64() -> UInt64 {
        let result = self.data[self.index..<self.index + 8].to(type: UInt64.self)
        self.index += 8
        return result
    }

    func uint32() -> UInt32 {
        let result = self.data[self.index..<self.index + 4].to(type: UInt32.self)
        self.index += 4
        return result
    }

    func uint16() -> UInt16 {
        let result = self.data[self.index..<self.index + 2].to(type: UInt16.self)
        self.index += 2
        return result
    }

}
