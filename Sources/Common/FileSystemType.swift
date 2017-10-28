// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum FileSystemType {
    // TODO: Sort alphabetically.
    /**
     One of many UNIX-like systems.

     - Note: Modern macOS systems also fall into this category.
     */
    case unix
    /// Older Macintosh systems.
    case macintosh
    case fat
    case ntfs
    case other
}
