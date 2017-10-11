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
}
