// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SevenZipFileInfo {
    init(_ pointerData: DataWithPointer) throws {

    }
//    BYTE NID::kFilesInfo;  (0x05)
//    UINT64 NumFiles
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
//    kEmptyStream:   (0x0E)
//    for(NumFiles)
//    BIT IsEmptyStream
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
