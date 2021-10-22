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

    let dependentBlocks = Flag("--dependent-blocks", description: "(Compression only) Use dependent blocks")
    let blockChecksums = Flag("--block-checksums", description: "(Compression only) Save checksums for compressed blocks")
    let noContentChecksum = Flag("--no-content-checksum", description: "(Compression only) Don't save the checksum of the uncompressed data")
    let contentSize = Flag("--content-size", description: "(Compression only) Save the size of the uncompressed data")
    
    let blockSize = Key<Int>("--block-size", description: "(Compression only) Use specified block size (in bytes; default and max: 4194304)")

    let dictionary = Key<String>("-D", "--dict", description: "Path to a dictionary to use in decompression or compression")
    let dictionaryID = Key<Int>("--dictID", description: "Optional dictionary ID (max: 4294967295)")

    var optionGroups: [OptionGroup] {
        let actions = OptionGroup(options: [compress, decompress], restriction: .exactlyOne)
        return [actions]
    }

    let input = Parameter()
    let output = OptionalParameter()

    func execute() throws {
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

        if dictID != nil && dictData == nil {
            print("ERROR: Dictionary ID is specified without specifying the dictionary itself.")
            exit(1)
        }

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

            let bs: Int
            if let blockSize = blockSize.value {
                if blockSize >= 4194304 {
                    print("ERROR: Too big block size.")
                    exit(1)
                }
                bs = blockSize
            } else {
                bs = 4 * 1024 * 1024
            }

            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)
            let compressedData = try LZ4.compress(data: fileData, independentBlocks: !dependentBlocks.value,
                blockChecksums: blockChecksums.value, contentChecksum: !noContentChecksum.value,
                contentSize: contentSize.value, blockSize: bs, dictionary: dictData, dictionaryID: dictID)
            try compressedData.write(to: outputURL)
        }
    }

}
