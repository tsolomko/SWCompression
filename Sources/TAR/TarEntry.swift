// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry from the TAR container.
public struct TarEntry: ContainerEntry {

    public let info: TarEntryInfo

    public let data: Data?

    public init(info: TarEntryInfo, data: Data?) {
        self.info = info
        self.data = data
    }

    func generateContainerData() throws -> Data {
        var out = try self.info.generateContainerData()
        guard let data = self.data
            else { return out }
        out.append(data)
        let paddingSize = data.count.roundTo512() - data.count
        out.append(Data(count: paddingSize))
        return out
    }

}
