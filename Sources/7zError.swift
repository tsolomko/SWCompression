// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum SevenZipError: Error {
    case wrongSignature
    case wrongFormatVersion

    case wrongCRC
    case wrongSize

    case startPosNotSupported
    case externalNotSupported
    case multiStreamNotSupported
    case additionalStreamsNotSupported
    case compressionNotSupported
    case encryptionNotSupported

    case dataIsUnavailable

    case internalStructureError
}
