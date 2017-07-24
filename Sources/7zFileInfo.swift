// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipFileInfo {

    struct File {
        var isEmptyStream = false
        var isEmptyFile = false
        var isAntiFile = false
    }

    let numFiles: Int
    var files = [File]()

    var properties = [(Int, [UInt8])]()

    init(_ pointerData: DataWithPointer) throws {
        numFiles = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
        for _ in 0..<numFiles {
            files.append(File())
        }
        while true {
            let propertyType = pointerData.byte()
            if propertyType == 0 {
                break
            }
            let size = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
            properties.append((propertyType.toInt(), pointerData.bytes(count: size)))

            // TODO: Add properties parsing.
        }
    }

}
