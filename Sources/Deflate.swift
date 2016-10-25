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
        let method = data[2]
        guard method == 8 else { throw DeflateError.UnknownCompressionMethod }

        // Next bytes present some service information
        let serviceInfo = ServiceInfo(magic: magic,
                                      method: method,
                                      flags: data[3],
                                      mtime: Data(data[4...7]).to(type: UInt64.self),
                                      extraFlags: data[8],
                                      osType: data[9])
        print("\(serviceInfo)")

        var startPoint = 10 // Index in data of 'actual data'

        // Some archives may contain extra fields
        if serviceInfo.flags & Flags.fextra != 0 {
            let xlen = Data(data[startPoint...startPoint + 1]).to(type: UInt16.self)
            startPoint += 2 + Int(bitPattern: UInt(xlen))
        }

        // Some archives may contain source file name (this part ends with zero byte)
        if serviceInfo.flags & Flags.fname != 0 {
            let fnameStart = startPoint
            while true {
                let byte = data[startPoint]
                startPoint += 1
                guard byte != 0 else { break }
            }
            print(String(data: Data(data[fnameStart..<startPoint - 1]), encoding: .utf8))
        }

        // Some archives may contain comment (this part also ends with zero)
        if serviceInfo.flags & Flags.fcomment != 0 {
            let fcommentStart = startPoint
            while true {
                let byte = data[startPoint]
                startPoint += 1
                guard byte != 0 else { break }
            }
            print(String(data: Data(data[fcommentStart..<startPoint - 1]), encoding: .utf8))
        }

        // Some archives may contain 2-bytes checksum
        if serviceInfo.flags & Flags.fhcrc != 0 {
            let crc = Data(data[startPoint...startPoint + 1]).to(type: UInt16.self)
            startPoint += 2
            print("\(crc)")
        }

        // Current point of processing in data
        var index = startPoint
        while true {
            // Is this a last block?
            let isLastBit = data[index][0]
            // Type of the current block
            let blockType = [UInt8](data[index][1..<3].reversed())

            if blockType == [0, 0] { // Uncompressed block
                // Get length of the uncompressed data

                // CHECK IF STRAIGHT CONVERSION TO INT WITH 'TO' METHOD WORKS
                let length = Int(bitPattern: UInt(Data(data[index...index + 1])
                    .to(type: UInt16.self)))
                index += 2
                // Get 1-complement of the length
                let nlength = Int(bitPattern: UInt(Data(data[index...index + 1])
                    .to(type: UInt16.self)))
                index += 2
                // Check if lengths are OK
                guard length & nlength == 0 else { throw DeflateError.WrongBlockLengths }
                // Process uncompressed data into the output
                output.append(Data(data[index..<index+length]))
            } else if blockType == [1, 0] || blockType == [0, 1] {
                // Block with Huffman coding (either static or dynamic)

                // Declaration of Huffman tables which will be populated and used later
                var mainLiterals: HuffmanTable
                var mainDistances: HuffmanTable

                if blockType == [0, 1] { // Static Huffman
                    // Bootstraps for tables
                    let staticHuffmanBootstrap = [[0, 8], [144, 9], [256, 7], [280, 8], [288, -1]]
                    let staticHuffmanLengthsBootstrap = [[0, 5], [32, -1]]
                    // Initialize tables from these bootstraps
                    mainLiterals = HuffmanTable(bootstrap: staticHuffmanBootstrap)
                    mainDistances = HuffmanTable(bootstrap: staticHuffmanLengthsBootstrap)
                } else if blockType == [1, 0] { // Dynamic Huffman

                }

            }

            // End the cycle if it was the last block
            if isLastBit == 1 { break }
        }

        return output
    }

}
