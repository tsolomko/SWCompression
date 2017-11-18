// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry from the TAR container.
public struct TarEntry: ContainerEntry {

    public let info: TarEntryInfo

    public let data: Data?

    init(_ entryInfo: TarEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.data = data
    }

}
