// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class XZCommand: Command {

    let name = "xz"
    let shortDescription = "Extracts XZ archive"

    let archive = Parameter()
    let outputPath = OptionalParameter()

    func execute() throws {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                        options: .mappedIfSafe)
        let outputPath = self.outputPath.value ?? FileManager.default.currentDirectoryPath
        let decompressedData = try XZArchive.unarchive(archive: fileData)
        try decompressedData.write(to: URL(fileURLWithPath: outputPath))
    }

}
