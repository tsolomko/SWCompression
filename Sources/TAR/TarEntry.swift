// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry from the TAR container.
public struct TarEntry: ContainerEntry {

    public var info: TarEntryInfo

    public var data: Data? {
        didSet {
            self.info.size = self.data?.count ?? 0
        }
    }

    public init(info: TarEntryInfo, data: Data?) {
        self.info = info
        self.info.size = data?.count ?? 0
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
