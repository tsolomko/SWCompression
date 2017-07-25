// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipFileInfo {

    struct File {
        var isEmptyStream = false
        var isEmptyFile = false
        var isAntiFile = false
    }

    let numFiles: Int
    var files = [File]()

    var properties = [SevenZipProperty]()

    init(_ pointerData: DataWithPointer) throws {
        numFiles = pointerData.szMbd().multiByteInteger
        for _ in 0..<numFiles {
            files.append(File())
        }
        properties = try SevenZipProperty.getProperties(pointerData)
    }

}
