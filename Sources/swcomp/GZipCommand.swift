// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class GZipCommand: Command {

    let name = "gz"
    let shortDescription = "Creates or extracts GZip archive"

    let compress = Flag("-c", "--compress", description: "Compress input file into GZip archive")
    let decompress = Flag("-d", "--decompress", description: "Decompress GZip archive")

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
            print(inputURL.pathExtension) // TODO:
            if let outputPath = output.value {
                outputURL = URL(fileURLWithPath: outputPath)
            } else if inputURL.pathExtension == "gz" {
                outputURL = inputURL.deletingPathExtension()
            } else {
                fatalError("""
                           Unable to get output path.
                           No output parameter was specified.
                           Extension was: \(inputURL.pathExtension)
                           """)
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let decompressedData = try GzipArchive.unarchive(archive: fileData)
            try decompressedData.write(to: outputURL)
        } else if compress.value {
            let inputURL = URL(fileURLWithPath: self.input.value)
            let fileName = inputURL.lastPathComponent

            let outputURL: URL
            if let outputPath = output.value {
                outputURL = URL(fileURLWithPath: outputPath)
            } else {
                outputURL = inputURL.appendingPathExtension("gz")
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let compressedData = try GzipArchive.archive(data: fileData,
                                                        fileName: fileName.isEmpty ? nil : fileName,
                                                        writeHeaderCRC: true)
            try compressedData.write(to: outputURL)
        } else {
            fatalError("Neither compress nor decompress option in GZipCommand.")
        }
    }

}
