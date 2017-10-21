// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class BZip2Command: Command {

    let name = "bz2-d"
    let shortDescription = "Extracts BZip2 archive"

    let archive = Parameter()
    let outputPath = OptionalParameter()

    func execute() throws {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                        options: .mappedIfSafe)
        let outputPath = self.outputPath.value ?? FileManager.default.currentDirectoryPath
        let decompressedData = try BZip2.decompress(data: fileData)
        try decompressedData.write(to: URL(fileURLWithPath: outputPath))
    }

}
