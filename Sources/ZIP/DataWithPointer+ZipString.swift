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
        let stringData = self.data[self.index..<self.index + length]
        self.index += length
        if useUtf8 {
            return String(data: stringData, encoding: .utf8)
        }
        if ZipString.cp437Available && !ZipString.needsUtf8(stringData) {
            return String(data: stringData, encoding: String.Encoding(rawValue:
                CFStringConvertEncodingToNSStringEncoding(ZipString.cp437Encoding)))
        } else {
            return String(data: stringData, encoding: .utf8)
        }
    }

}
