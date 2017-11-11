// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

#if os(Linux)
    import CoreFoundation
#endif

extension DataWithPointer {

    func getZipStringField(_ length: Int, _ useUtf8: Bool) -> String? {
        guard length > 0
            else { return "" }
        let bytes = self.bytes(count: length)
        let bytesAreUtf8 = ZipString.needsUtf8(bytes)
        if !useUtf8 && ZipString.cp437Available && !bytesAreUtf8 {
            return String(data: Data(bytes: bytes), encoding: String.Encoding(rawValue:
                CFStringConvertEncodingToNSStringEncoding(ZipString.cp437Encoding)))
        } else {
            return String(data: Data(bytes: bytes), encoding: .utf8)
        }
    }

}
