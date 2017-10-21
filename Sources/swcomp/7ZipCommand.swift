// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class SevenZipCommand: Command {

    let name = "7z"
    let shortDescription = "Extracts 7-Zip container"

    let info = Flag("-i", "--info", usage: "Print list of entries in container and their attributes")
    let extract = Key<String>("-e", "--extract", usage: "Extract container into specified directory (it must be empty or not exist)")

    var optionGroups: [OptionGroup] {
        let actions = OptionGroup(options: [info, extract], restriction: .exactlyOne)
        return [actions]
    }

    let archive = Parameter()

    func execute() throws {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                                options: .mappedIfSafe)
        if info.value {
            let entries = try SevenZipContainer.open(container: fileData)
            swcomp.printInfo(entries)
        } else {
            let outputPath = self.extract.value ?? FileManager.default.currentDirectoryPath

            if try !isValidOutputDirectory(outputPath, create: true) {
                print("ERROR: Specified path already exists and is not a directory.")
                exit(1)
            }

            let entries = try SevenZipContainer.open(container: fileData)
            try swcomp.write(entries, outputPath, verbose.value)
        }
    }
}
