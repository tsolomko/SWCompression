//
//  ZipContainer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.01.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

public enum ZipError: Error {
    case NotFoundCentralDirectoryEnd
    case WrongCentralDirectoryDisk
}

public class ZipContainer {

    public static func open(containerData data: Data) throws -> [String: Data] {
        /// Object with input data which supports convenient work with bit shifts.
        var pointerData = DataWithPointer(data: data, bitOrder: .reversed)

        // Looking for the end of central directory record.
        pointerData.index = pointerData.size - 22
        while true {
            let signature = pointerData.uint64FromAlignedBytes(count: 4)
            if signature == 0x06054b50 {
                // We found it!
                break
            }
            if pointerData.index == 0 {
                throw ZipError.NotFoundCentralDirectoryEnd
            }
            pointerData.index -= 5
        }
        let diskNumber = pointerData.uint64FromAlignedBytes(count: 2)
        let centralDirectoryDiskNumber = pointerData.uint64FromAlignedBytes(count: 2)
        guard diskNumber == centralDirectoryDiskNumber
            else { throw ZipError.WrongCentralDirectoryDisk }


        return [:]
    }

}
