// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class ZipCommand: Command {

    let name = "zip"
    let shortDescription = "Extracts ZIP container"

    let info = Flag("-i", "--info", description: "Print list of entries in container and their attributes")
    let extract = Key<String>("-e", "--extract", description: "Extract container into specified directory")

    let verbose = Flag("--verbose", description: "Print the list of extracted files and directories.")

    var optionGroups: [OptionGroup] {
        let actions = OptionGroup(options: [info, extract], restriction: .exactlyOne)
        return [actions]
    }

    let archive = Parameter()

    func execute() throws {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                                options: .mappedIfSafe)
        if info.value {
            let entries = try ZipContainer.info(container: fileData)
            swcomp.printInfo(entries)
        } else {
            let outputPath = self.extract.value!

            if try !isValidOutputDirectory(outputPath, create: true) {
                print("ERROR: Specified path already exists and is not a directory.")
                exit(1)
            }

            let entries = try ZipContainer.open(container: fileData)
            try swcomp.write(entries, outputPath, verbose.value)
        }
    }

}
