// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class LZ4Command: Command {

    let name = "lz4"
    let shortDescription = "Creates or extracts a LZ4 archive"

    let compress = Flag("-c", "--compress", description: "Compress an input file into a LZ4 archive")
    let decompress = Flag("-d", "--decompress", description: "Decompress a LZ4 archive")

    var optionGroups: [OptionGroup] {
        let actions = OptionGroup(options: [compress, decompress], restriction: .exactlyOne)
        return [actions]
    }

    let input = Parameter()
    let output = OptionalParameter()

    func execute() throws {
        if decompress.value {
            let inputURL = URL(fileURLWithPath: self.input.value)

            let outputURL: URL
            if let outputPath = output.value {
                outputURL = URL(fileURLWithPath: outputPath)
            } else if inputURL.pathExtension == "lz4" {
                outputURL = inputURL.deletingPathExtension()
            } else {
                print("""
                      ERROR: Unable to get output path. \
                      No output parameter was specified. \
                      Extension was: \(inputURL.pathExtension)
                      """)
                exit(1)
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let decompressedData = try LZ4.decompress(data: fileData)
            try decompressedData.write(to: outputURL)
        } else if compress.value {
            print("LZ4 compression is not implemented yet")
            exit(1)
        }
    }

}
