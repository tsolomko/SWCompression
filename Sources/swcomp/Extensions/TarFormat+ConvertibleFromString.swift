// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import SwiftCLI
import SWCompression

// This extension allows to use TarContainer.Format as a Key option.
extension TarContainer.Format: ConvertibleFromString {

    public init?(input: String) {
        switch input {
        case "prePosix":
            self = .prePosix
        case "ustar":
            self = .ustar
        case "gnu":
            self = .gnu
        case "pax":
            self = .pax
        default:
            return nil
        }
    }

}
