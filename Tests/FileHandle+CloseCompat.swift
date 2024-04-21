// Copyright (c) 2024 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license informations

import Foundation

extension FileHandle {

    func closeCompat() throws {
        if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
            try self.close()
        } else {
            self.closeFile()
        }
    }

}
