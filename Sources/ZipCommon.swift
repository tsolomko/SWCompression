// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

#if os(Linux)
    import CoreFoundation
#endif

class ZipCommon {

    #if os(Linux)
        static let cp437Encoding: CFStringEncoding = UInt32(truncatingBitPattern: UInt(kCFStringEncodingDOSLatinUS))
        static let cp437Available: Bool = CFStringIsEncodingAvailable(cp437Encoding)
    #else
        static let cp437Encoding = CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)
        static let cp437Available = CFStringIsEncodingAvailable(cp437Encoding)
    #endif

    static func getStringField(_ pointerData: DataWithPointer, _ length: Int, _ useUtf8: Bool) -> String? {
        let bytes = pointerData.bytes(count: length)
        let bytesAreUtf8 = ZipCommon.isUtf8(bytes)
        if !useUtf8 && ZipCommon.cp437Available && !bytesAreUtf8 {
            return String(data: Data(bytes: bytes), encoding: String.Encoding(rawValue:
                CFStringConvertEncodingToNSStringEncoding(ZipCommon.cp437Encoding)))
        } else {
            return String(data: Data(bytes: bytes), encoding: .utf8)
        }
    }

    static func isUtf8(_ bytes: [UInt8]) -> Bool {
        var codeLength = 0
        var index = 0
        var ch: UInt32 = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte <= 0x7F {
                index += 1
                continue
            }

            if byte >= 0xC2 && byte <= 0xDF {
                codeLength = 2
            } else if byte >= 0xE0 && byte <= 0xEF {
                codeLength = 3
            } else if byte >= 0xF0 && byte <= 0xF4 {
                codeLength = 4
            } else {
                return false
            }
            if index + codeLength - 1 >= bytes.count {
                return false
            }

            for i in 1..<codeLength {
                if bytes[index + i] & 0xC0 != 0x80 {
                    return false
                }
            }

            if codeLength == 2 {
                ch = ((UInt32(bytes[index]) & 0x1F) << 6) + (UInt32(bytes[index + 1]) & 0x3F)
            } else if codeLength == 3 {
                ch = ((UInt32(bytes[index]) & 0x0F) << 12) + ((UInt32(bytes[index + 1]) & 0x3F) << 6) +
                    (UInt32(bytes[index + 2]) & 0x3F)
                if ch < 0x0800 {
                    return false
                }
                if ch >> 11 == 0x1B {
                    return false
                }
            } else if codeLength == 4 {
                ch = ((UInt32(bytes[index]) & 0x07) << 18) + ((UInt32(bytes[index + 1]) & 0x3F) << 12) +
                    ((UInt32(bytes[index + 2]) & 0x3F) << 6) + (UInt32(bytes[index + 3]) & 0x3F)
                if ch < 0x10000 || ch > 0x10FFFF {
                    return false
                }
            }
            index += codeLength
        }
        return true
    }


}
