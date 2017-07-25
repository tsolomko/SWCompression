// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class SevenZipProperty {

    let type: UInt8
    let size: Int
    let bytes: [UInt8]

    init(_ type: UInt8, _ size: Int, _ bytes: [UInt8]) {
        self.type = type
        self.size = size
        self.bytes = bytes
    }

    static func getProperties(_ pointerData: DataWithPointer) throws -> [SevenZipProperty] {
        var properties = [SevenZipProperty]()
        while true {
            let propertyType = pointerData.byte()
            if propertyType == 0 {
                break
            }
            let propertySize = pointerData.szMbd().multiByteInteger
            properties.append(SevenZipProperty(propertyType, propertySize, pointerData.bytes(count: propertySize)))
        }
        return properties
    }
    
}
