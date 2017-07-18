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

    init(_ pointerData: DataWithPointer) throws {
        numFiles = try pointerData.multiByteDecode(SevenZipError.multiByteIntegerError).multiByteInteger
        for _ in 0..<numFiles {
            files.append(File())
        }
        let bitReader = BitReader(data: pointerData.data, bitOrder: .reversed) // TODO: bitOrder ???
        var totalEmptyStreams = 0
        while true {
            let propertyType = pointerData.byte()
            if propertyType == 0 {
                break
            }
            switch propertyType {
            case 0x0E: // Empty stream
                for i in 0..<numFiles {
                    let isEmptyStream = bitReader.bit() != 0
                    files[i].isEmptyStream = isEmptyStream
                    totalEmptyStreams += isEmptyStream ? 1 : 0 // TODO: Should we skipUntilNextByte() ???
                }
            case 0x0F: // Empty file
                break
            default:
                break // TODO: Should we throw error?
            }
        }
    }
//
//    for (;;)
//    {
//    BYTE PropertyType;
//    if (aType == 0)
//    break;
//
//    UINT64 Size;
//
//    switch(PropertyType)
//    {
//
//    kEmptyFile:     (0x0F)
//    for(EmptyStreams)
//    BIT IsEmptyFile
//
//    kAnti:          (0x10)
//    for(EmptyStreams)
//    BIT IsAntiFile
//
//    case kCTime: (0x12)
//    case kATime: (0x13)
//    case kMTime: (0x14)
//    BYTE AllAreDefined
//    if (AllAreDefined == 0)
//    {
//    for(NumFiles)
//    BIT TimeDefined
//    }
//    BYTE External;
//    if(External != 0)
//    UINT64 DataIndex
//    []
//    for(Definded Items)
//    UINT64 Time
//    []
//
//    kNames:     (0x11)
//    BYTE External;
//    if(External != 0)
//    UINT64 DataIndex
//    []
//    for(Files)
//    {
//    wchar_t Names[NameSize];
//    wchar_t 0;
//    }
//    []
//
//    kAttributes:  (0x15)
//    BYTE AllAreDefined
//    if (AllAreDefined == 0)
//    {
//    for(NumFiles)
//    BIT AttributesAreDefined
//    }
//    BYTE External;
//    if(External != 0)
//    UINT64 DataIndex
//    []
//    for(Definded Attributes)
//    UINT32 Attributes
//    []
//    }
//    }
}
