// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum FileSystemType {
    case fat
    /// Older Macintosh systems.
    case macintosh
    case ntfs
    case other
    /**
     One of many UNIX-like systems.

     - Note: Modern macOS systems also fall into this category.
     */
    case unix
}
