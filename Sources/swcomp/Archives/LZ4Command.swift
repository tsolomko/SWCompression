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

    let dictionary = Key<String>("-D", "--dict", description: "Path to a dictionary to use in decompression or compression")
    let dictionaryID = Key<Int>("--dictID", description: "Optional dictionary ID; must less than or equal to 4294967295.")

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

            let dictID: UInt32?
            if let dictionaryID = dictionaryID.value {
                guard dictionaryID <= UInt32.max
                    else { print("ERROR: Too large dictionary ID."); exit(1) }
                dictID = UInt32(truncatingIfNeeded: dictionaryID)
            } else {
                dictID = nil
            }

            let dictData: Data?
            if let dictionary = dictionary.value {
                dictData = try Data(contentsOf: URL(fileURLWithPath: dictionary), options: .mappedIfSafe)
            } else {
                dictData = nil
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let decompressedData = try LZ4.decompress(data: fileData, dictionary: dictData, dictionaryID: dictID)
            try decompressedData.write(to: outputURL)
        } else if compress.value {
            let inputURL = URL(fileURLWithPath: self.input.value)
            let fileName = inputURL.lastPathComponent

            let outputURL: URL
            if let outputPath = output.value {
                outputURL = URL(fileURLWithPath: outputPath)
            } else {
                outputURL = inputURL.appendingPathExtension("lz4")
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let compressedData = try LZ4.compress(data: fileData)
            try compressedData.write(to: outputURL)
        }
    }

}
