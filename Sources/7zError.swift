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
    case wrongHeaderCRC
    case wrongExternal
    case reservedCodecFlags
    case unknownNumFolders
    case wrongEnd
    case externalNotSupported
    case altMethodsNotSupported
    case wrongStreamsNumber
    case multiStreamNotSupported
    case compressionNotSupported
    case wrongDataSize
    case wrongCRC
    case wrongCoderProperties
    case noPackInfo
    case wrongFileProperty
    case wrongFileNameLength
    case wrongFileNames
    case startPosNotSupported
    case incompleteProperty
    case additionalStreamsNotSupported
    case noFileSize
    case notEnoughFolders
    case notEnoughStreams
    case noStreamFound
    case noPackInfoFound
    case streamOverread
    case dataIsUnavailable
    case encryptionNotSupported
}
