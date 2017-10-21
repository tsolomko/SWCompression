// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents either a file or directory entry in ZIP container.
public struct ZipEntry: ContainerEntry {

    /// Various information about entry.
    public let info: ZipEntryInfo

    public let data: Data?

    init(_ entryInfo: ZipEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.data = data
    }

}
