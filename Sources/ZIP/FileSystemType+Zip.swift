// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension FileSystemType {

    init?(_ versionMadeBy: UInt16) {
        switch (versionMadeBy & 0xFF00) >> 8 {
        case 0, 14:
            self = .fat
        case 3:
            self = .unix
        case 7, 19:
            self = .macintosh
        case 10:
            self = .ntfs
        case 1, 2, 4, 5, 6, 8, 9, 11, 12, 13, 15, 16, 17, 18:
            self = .other
        default:
            return nil
        }
    }

}
