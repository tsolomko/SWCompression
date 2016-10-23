//
//  Deflate.swift
//  SWCompression
//
//  Created by Timofey Solomko on 23.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

extension UInt8 {

    subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < 8, "Index must be between 0 and 7 (included)")
        let uindex = UInt8(truncatingBitPattern: index)
        return (self & (0x1 << uindex)) >> uindex
    }

    subscript(range: CountableRange<Int>) -> [UInt8] {
        return range.map {
            let uindex = UInt8(truncatingBitPattern: $0)
            return (self & (0x1 << uindex)) >> uindex
        }
    }
}



public enum DeflateError: Error {
    case WrongMagic
    case UnknownCompressionMethod
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

        let magic = data.bytes(from: 0..<2)
        guard magic == [31, 139] else { throw DeflateError.WrongMagic }

        let method = data.byte(at: 2)
        guard method == 8 else { throw DeflateError.UnknownCompressionMethod }

        let serviceInfo = ServiceInfo(magic: magic,
                                      method: method,
                                      flags: data.byte(at: 3),
                                      mtime: Data(data[4...7]).to(type: UInt64.self),
                                      extraFlags: data.byte(at: 8),
                                      osType: data.byte(at: 9))

        print("\(serviceInfo)")

        var startPoint = 0
        if serviceInfo.flags & Flags.fextra != 0 {
            let xlen = Data(data[10...11]).to(type: UInt32.self)
            print("\(xlen)")
        }

        return output
    }

}
