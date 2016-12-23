//
//  LZMAOutWindow.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

final class LZMAOutWindow {

    private var byteBuffer: [UInt8]
    private var position: Int
    private var size: Int
    private var isFull: Bool

    private(set) var totalPosition: Int

    var isEmpty: Bool {
        return self.position == 0 && !self.isFull
    }

    init(dictSize: Int) {
        self.byteBuffer = Array(repeating: 0, count: dictSize)
        self.position = 0
        self.totalPosition = 0
        self.size = dictSize
        self.isFull = false
    }

    func put(_
        byte: UInt8, _ out: inout [UInt8], _ outIndex: inout Int,
                     _ uncompressedSize: inout Int) {
        self.totalPosition += 1
        self.byteBuffer[position] = byte
        self.position += 1
        if self.position == self.size {
            self.position = 0
            self.isFull = true
        }

        if uncompressedSize > 0 {
            out[outIndex] = byte
            outIndex += 1
        } else {
            out.append(byte)
        }
        uncompressedSize -= 1
    }

    func byte(at distance: Int) -> UInt8 {
        return self.byteBuffer[distance <= self.position ? self.position - distance :
            self.size - distance + self.position]
    }

    func copyMatch(at distance: Int, length: Int, _ out: inout [UInt8], _ outIndex: inout Int,
                   _ uncompressedSize: inout Int) {
        for _ in 0..<length {
            self.put(self.byte(at: distance), &out, &outIndex, &uncompressedSize)
        }
    }

    func check(distance: Int) -> Bool {
        return distance <= self.position || self.isFull
    }

}
