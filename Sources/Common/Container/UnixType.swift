// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents file type in UNIX format.
public enum UnixType: UInt32 {
    /// FIFO special file.
    case fifo = 0o010000
    /// Character special file.
    case characterSpecial = 0o020000
    /// Directory.
    case directory = 0o040000
    /// Block special file.
    case blockSpecial = 0o060000
    /// Regular file.
    case regular = 0o100000
    /// Symbolic link.
    case symbolicLink = 0o120000
    /// Socket.
    case socket = 0o140000
}
