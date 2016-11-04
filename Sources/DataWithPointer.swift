//
//  DataWithPointer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 01.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation
import CoreFoundation

class DataWithPointer {

    /// Only needed for creation of bitVector in initData()
    let data: Data
    
    private(set) var bitVector: CFBitVector?
    private(set) var index: Int
    private(set) var bitShift: Int

    init(data: Data) {
        self.data = data
        self.index = 0
        self.bitShift = 0
        self.bitVector = nil
        initData()
    }

    private func initData() {
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            self.bitVector = CFBitVectorCreate(kCFAllocatorDefault, bytes, data.count * 8)
        }
    }

    func bits(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }

        /// Start point of bits to return
        let startIndex = self.index * 8 + self.bitShift
        /// Range of bits to return in bitVector
        let range = CFRangeMake(startIndex, count)

        var array: [UInt8] = Array(repeating: 0, count: count)
        CFBitVectorGetBits(self.bitVector!, range, &array)

        // Update index and bitShift
        let amountOfBytes = (count - self.bitShift) / 8
        self.index += amountOfBytes
        self.bitShift = count - 8 * amountOfBytes

        return array
    }

    func bit() -> UInt8 {
        return self.bits(count: 1).first!
    }

    /// Use with caution: not effective.
    func data(ofBytes count: Data.Index) -> Data {
        precondition(self.bitShift == 0, "Misaligned byte.")
        let returnData = Data(data[index..<index+count])
        index += count
        return returnData
    }

    // MARK: Manipulation with index and bitShift

    func skipUntilNextByte() {
        self.index += 1
        self.bitShift = 0
    }

    func rewind(bitsCount: Int) {
        let amountOfBytes = (bitsCount - self.bitShift) / 8
        self.index -= amountOfBytes
        self.bitShift = bitsCount - 8 * amountOfBytes
    }


}
