// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension ContainerEntryType {

    init(from fileTypeIndicator: UInt8) {
        switch fileTypeIndicator {
        case 0, 48: // "0"
            self = .regular
        case 49: // "1"
            self = .hardLink
        case 50: // "2"
            self = .symbolicLink
        case 51: // "3"
            self = .characterSpecial
        case 52: // "4"
            self = .blockSpecial
        case 53: // "5"
            self = .directory
        case 54: // "6"
            self = .fifo
        case 55: // "7"
            self = .contiguous
        default:
            self = .unknown
        }
    }

}
