// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum ContainerEntryType {
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
    /// Entry type is unknown.
    case unknown

    init(from unixType: UnixType) {
        switch unixType {
        case .fifo:
            self = .fifo
        case .characterSpecial:
            self = .characterSpecial
        case .directory:
            self = .directory
        case .blockSpecial:
            self = .blockSpecial
        case .regular:
            self = .regular
        case .symbolicLink:
            self = .symbolicLink
        case .socket:
            self = .socket
        }
    }
}
