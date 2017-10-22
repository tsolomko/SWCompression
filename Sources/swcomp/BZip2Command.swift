// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class BZip2Command: Command {

    let name = "bz2"
    let shortDescription = "Creates or extracts BZip2 archive"

    let compress = Flag("-c", "--compress", description: "Compress input file into BZip2 archive")
    let decompress = Flag("-d", "--decompress", description: "Decompress BZip2 archive")

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
            } else if inputURL.pathExtension == "bz2" {
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
            let decompressedData = try BZip2.decompress(data: fileData)
            try decompressedData.write(to: outputURL)
        } else if compress.value {
            let inputURL = URL(fileURLWithPath: self.input.value)

            let outputURL: URL
            if let outputPath = output.value {
                outputURL = URL(fileURLWithPath: outputPath)
            } else {
                outputURL = inputURL.appendingPathExtension("bz2")
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let compressedData = BZip2.compress(data: fileData)
            try compressedData.write(to: outputURL)
        } else {
            print("ERROR: Neither compress nor decompress option in BZip2Command.")
            exit(1)
        }
    }

}
