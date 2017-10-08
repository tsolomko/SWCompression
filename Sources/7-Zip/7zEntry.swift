// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry in 7-Zip container.
public class SevenZipEntry: ContainerEntry {

    /// Various information about entry.
    public let info: SevenZipEntryInfo

    public let data: Data?

    init(_ entryInfo: SevenZipEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.data = data
    }

}
