// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents type of a container entry.
public enum ContainerEntryType {
    /// Block special file.
    case blockSpecial
    /// Character special file.
    case characterSpecial
    /// Contiguous file.
    case contiguous
    /// Directory.
    case directory
    /// FIFO special file.
    case fifo
    /// Hard link.
    case hardLink
    /// Regular file.
    case regular
    /// Socket.
    case socket
    /// Symbolic link.
    case symbolicLink
    /// Entry type is unknown.
    case unknown

    init?(_ unixType: UInt32) {
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
