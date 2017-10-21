// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class CompressBZip2Command: Command {

    let name = "bz2-c"
    let shortDescription = "Creates BZip2 archive"

    let inputFile = Parameter()
    let outputArchive = Parameter()

    func execute() throws {
        let inputURL = URL(fileURLWithPath: self.inputFile.value)
        let outputURL = URL(fileURLWithPath: self.outputArchive.value)
        let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
        let compressedData = BZip2.compress(data: fileData)
        try compressedData.write(to: outputURL)
    }

}
