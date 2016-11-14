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
    
    fileprivate(set) var bitVector: CFBitVector?
    fileprivate(set) var index: Int
    fileprivate(set) var bitShift: Int

    init(data: Data) {
        self.data = data
        self.index = 0
        self.bitShift = 0
        self.bitVector = nil
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            self.bitVector = CFBitVectorCreate(kCFAllocatorDefault, bytes, data.count * 8)
        }
    }

    func bits(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }

        var array: [UInt8] = []
        for _ in 0..<count {
            let currentIndex = 8 * (index + 1) - bitShift - 1
            array.append(UInt8(truncatingBitPattern: CFBitVectorGetBitAtIndex(self.bitVector!, currentIndex)))
            self.bitShift += 1
            if self.bitShift >= 8 {
                self.bitShift = 0
                self.index += 1
            }
        }

        return array
    }

    func intFromBits(count: Int) -> Int {
        guard count > 0 else { return 0 }
        var result = 0
        for i in 0..<count {
            let currentIndex = 8 * (index + 1) - bitShift - 1
            result += Int(pow(Double(2), Double(i))) *
                Int(bitPattern: UInt(CFBitVectorGetBitAtIndex(self.bitVector!, currentIndex)))
            self.bitShift += 1
            if self.bitShift >= 8 {
                self.bitShift = 0
                self.index += 1
            }
        }

        return result
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
        let amountOfBytes = (bitsCount - self.bitShift) / 8 + 1
        self.index -= amountOfBytes
        self.bitShift = 8 - (bitsCount - self.bitShift) % 8

        if self.bitShift == 8 {
            self.index += 1
            self.bitShift = 0
        }
    }

}

class DataWithStraightPointer: DataWithPointer {

    override func bits(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }

        var array: [UInt8] = []
        for _ in 0..<count {
            let currentIndex = 8 * index + bitShift
            array.append(UInt8(truncatingBitPattern: CFBitVectorGetBitAtIndex(self.bitVector!, currentIndex)))
            self.bitShift += 1
            if self.bitShift >= 8 {
                self.bitShift = 0
                self.index += 1
            }
        }

        return array
    }

    override func intFromBits(count: Int) -> Int {
        guard count > 0 else { return 0 }
        var result = 0
        for i in 0..<count {
            let currentIndex = 8 * index + bitShift
            result += Int(pow(Double(2), Double(count - i - 1))) *
                Int(bitPattern: UInt(CFBitVectorGetBitAtIndex(self.bitVector!, currentIndex)))
            self.bitShift += 1
            if self.bitShift >= 8 {
                self.bitShift = 0
                self.index += 1
            }
        }
        
        return result
    }

}
