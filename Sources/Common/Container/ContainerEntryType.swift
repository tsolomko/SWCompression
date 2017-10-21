// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum ContainerEntryType {
    // TODO: Sort alphabetically.
    /// FIFO special file.
    case fifo
    /// Character special file.
    case characterSpecial
    /// Directory.
    case directory
    /// Block special file.
    case blockSpecial
    /// Regular file.
    case regular
    /// Symbolic link.
    case symbolicLink
    /// Socket.
    case socket
    /// Hard link.
    case hardLink
    /// Contiguous file.
    case contiguous
    /// Entry type is unknown.
    case unknown

    init?(from unixType: UInt32) {
        switch unixType {
        case 0o010000:
            self = .fifo
        case 0o020000:
            self = .characterSpecial
        case 0o040000:
            self = .directory
        case 0o060000:
            self = .blockSpecial
        case 0o100000:
            self = .regular
        case 0o120000:
            self = .symbolicLink
        case 0o140000:
            self = .socket
        default:
            return nil
        }
    }

}
