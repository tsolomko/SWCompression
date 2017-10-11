// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension ContainerEntryType {

    init(from fileTypeIndicator: String) {
        switch fileTypeIndicator {
        case "0":
            self = .regular
        case "1":
            self = .hardLink
        case "2":
            self = .symbolicLink
        case "3":
            self = .characterSpecial
        case "4":
            self = .blockSpecial
        case "5":
            self = .directory
        case "6":
            self = .fifo
        case "7":
            self = .contiguous
        default:
            self = .unknown
        }
    }
}
