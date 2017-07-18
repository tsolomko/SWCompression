// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public class SevenZipContainer: Container {

    public static func open(container data: Data) throws -> [ContainerEntry] {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)

        // SignatureHeader

        // Check signature.
        guard pointerData.bytes(count: 6) == [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
            else { throw SevenZipError.wrongSignature }

        // Check archive version.
        guard pointerData.bytes(count: 2) == [0, 2]
            else { throw SevenZipError.wrongVersion }

//        ArchiveVersion
//            {
//                BYTE Major;   // now = 0
//                BYTE Minor;   // now = 2
//        };
//
//        UINT32 StartHeaderCRC;
//
//        StartHeader
//            {
//                REAL_UINT64 NextHeaderOffset
//                REAL_UINT64 NextHeaderSize
//                UINT32 NextHeaderCRC
//        }

        return []
    }

}
