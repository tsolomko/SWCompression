// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipCoderInfo {

    let numFolders: Int

    let external: UInt8
    var folders: [SevenZipFolder]?
    var dataStreamIndex: Int?

    init(_ pointerData: DataWithPointer) throws {
        guard pointerData.byte() == 0x0B
            else { throw SevenZipError.wrongPropertyID }
        numFolders = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
        external = pointerData.byte()
        switch external {
        case 0:
            folders = []
            for _ in 0..<numFolders {
                folders?.append(try SevenZipFolder(pointerData))
            }
        case 1:
            dataStreamIndex = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
        default:
            throw SevenZipError.wrongExternal
        }

        // TODO:
        //
        //    BYTE ID::kCodersUnPackSize  (0x0C)
        //    for(Folders)
        //    for(Folder.NumOutStreams)
        //    UINT64 UnPackSize;
        //
        //
        //    []
        //    BYTE NID::kCRC   (0x0A)
        //    UnPackDigests[NumFolders]
        //    []
        //    
        //    
        //    
        //    BYTE NID::kEnd

    }
}
