// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry in 7-Zip container.
public struct TarEntry: ContainerEntry {

    /// Various information about entry.
    public let info: TarEntryInfo

    public let data: Data?

    init(_ entryInfo: TarEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.data = data
    }

}
