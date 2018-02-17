// Copyright (c) 2018 Timofey Solomko
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

    let one = Flag("-1", description: "Set block size to 100k (default); only used for compression")
    let two = Flag("-2", description: "Set block size to 200k; only used for compression")
    let three = Flag("-3", description: "Set block size to 300k; only used for compression")
    let four = Flag("-4", description: "Set block size to 400k; only used for compression")
    let five = Flag("-5", description: "Set block size to 500k; only used for compression")
    let six = Flag("-6", description: "Set block size to 600k; only used for compression")
    let seven = Flag("-7", description: "Set block size to 700k; only used for compression")
    let eight = Flag("-8", description: "Set block size to 800k; only used for compression")
    let nine = Flag("-9", description: "Set block size to 900k; only used for compression")

    var optionGroups: [OptionGroup] {
        let actions = OptionGroup(options: [compress, decompress], restriction: .exactlyOne)
        let blockSizes = OptionGroup(options: [one, two, three, four, five, six, seven, eight, nine],
                                     restriction: .atMostOne)
        return [actions, blockSizes]
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

            let blockSize: BZip2.BlockSize
            if one.value {
                blockSize = .one
            } else if two.value {
                blockSize = .two
            } else if three.value {
                blockSize = .three
            } else if four.value {
                blockSize = .four
            } else if five.value {
                blockSize = .five
            } else if six.value {
                blockSize = .six
            } else if seven.value {
                blockSize = .seven
            } else if eight.value {
                blockSize = .eight
            } else if nine.value {
                blockSize = .nine
            } else {
                blockSize = .one
            }

            let compressedData = BZip2.compress(data: fileData, blockSize: blockSize)
            try compressedData.write(to: outputURL)
        }
    }

}
