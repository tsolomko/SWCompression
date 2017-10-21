// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class CompressGZipCommand: Command {

    let name = "gz-c"
    let shortDescription = "Creates GZip archive"

    let inputFile = Parameter()
    let outputArchive = Parameter()

    func execute() throws {
        let inputURL = URL(fileURLWithPath: self.inputFile.value)
        let outputURL = URL(fileURLWithPath: self.outputArchive.value)
        let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
        let fileName = inputURL.lastPathComponent
        let compressedData = try GzipArchive.archive(data: fileData,
                                                     fileName: fileName.isEmpty ? nil : fileName,
                                                     writeHeaderCRC: true)
        try compressedData.write(to: outputURL)
    }

}
