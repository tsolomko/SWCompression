// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum SevenZipError: Error {
    case wrongSignature
    case wrongVersion
    case wrongStartHeaderCRC
    case wrongHeaderSize
    case wrongPropertyID
    case multiByteIntegerError
    case wrongHeaderCRC
    case wrongExternal
    case reservedCodecFlags
    case unknownNumFolders
}
