//
//  Deflate.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

public enum DeflateError: Error {
    case WrongMagic
    case UnknownCompressionMethod
    case WrongBlockLengths
}

public class Deflate {

    struct Flags {
        static let ftext: UInt8 = 0x01
        static let fhcrc: UInt8 = 0x02
        static let fextra: UInt8 = 0x04
        static let fname: UInt8 = 0x08
        static let fcomment: UInt8 = 0x10
    }

    struct ServiceInfo {
        let magic: [UInt8]
        let method: UInt8
        let flags: UInt8
        let mtime: UInt64
        let extraFlags: UInt8
        let osType: UInt8
    }

    public static func decompress(data: Data) throws -> Data {
        var output = Data()

        // First two bytes should be correct 'magic' bytes
        let magic = data.bytes(from: 0..<2)
        guard magic == [31, 139] else { throw DeflateError.WrongMagic }

        // Third byte is a method of compression. Only type 8 (DEFLATE) compression is supported
        let method = data.byte(at: 2)
        guard method == 8 else { throw DeflateError.UnknownCompressionMethod }

        // Next bytes present some service information
        let serviceInfo = ServiceInfo(magic: magic,
                                      method: method,
                                      flags: data.byte(at: 3),
                                      mtime: Data(data[4...7]).to(type: UInt64.self),
                                      extraFlags: data.byte(at: 8),
                                      osType: data.byte(at: 9))
        print("\(serviceInfo)")

        var startPoint = 10 // Index in data of 'actual data'

        // Some archives may contain extra fields
        if serviceInfo.flags & Flags.fextra != 0 {
            let xlen = Data(data[10...11]).to(type: UInt16.self)
            startPoint += 2 + Int(bitPattern: UInt(xlen))
        }

        // Some archives may contain source file name (this part ends with zero byte)
        if serviceInfo.flags & Flags.fname != 0 {
            let fnameStart = startPoint
            while true {
                let byte = data.byte(at: startPoint)
                startPoint += 1
                guard byte != 0 else { break }
            }
            print(String(data: data.subdata(in: fnameStart..<startPoint - 1), encoding: .utf8))
        }

        // Some archives may contain comment (this part also ends with zero)
        if serviceInfo.flags & Flags.fcomment != 0 {
            let fcommentStart = startPoint
            while true {
                let byte = data.byte(at: startPoint)
                startPoint += 1
                guard byte != 0 else { break }
            }
            print(String(data: data.subdata(in: fcommentStart..<startPoint - 1), encoding: .utf8))
        }

        // Some archives may contain 2-bytes checksum
        if serviceInfo.flags & Flags.fhcrc != 0 {
            let crc = Data(data[startPoint...startPoint + 1]).to(type: UInt16.self)
            startPoint += 2
            print("\(crc)")
        }

        var index = startPoint
        while true {
            let isLastBit = data.byte(at: index)[0]
            let blockType = data.byte(at: index)[1..<3]

            let align = 3

            if blockType == [0, 0] { // Uncompressed
                let lengthArray = data.bytes(from: index..<index + 2)
                let length = lengthArray[0].combine(withByte: lengthArray[1])
                index += 2
                let nlengthArray = data.bytes(from: index..<index + 2)
                let nlength = nlengthArray[0].combine(withByte: nlengthArray[1])
                index += 2
                guard length & nlength == 0 else { throw DeflateError.WrongBlockLengths }
                output.append(data.bytes(from: index..<(index + Int(length))), count: Int(length))
            } else if blockType == [1, 0] || blockType == [0, 1] { // Huffman coding (either static or dynamic)
                if blockType == [0, 1] { // Static Huffman
                    let staticHuffmanBootstrap = [[0, 8],
                                                  [144, 9],
                                                  [256, 7],
                                                  [280, 8],
                                                  [288, -1]]
                    let staticHuffmanLengthsBootstrap = [[0, 5],
                                                         [32, -1]]
                } else if blockType == [1, 0] { // Dynamic Huffman

                }

            }

            if isLastBit == 1 { break }
        }

        return output
    }

}
