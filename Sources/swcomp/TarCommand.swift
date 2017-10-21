// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class TarCommand: Command {

    let name = "tar"
    let shortDescription = "Extracts TAR container"

    let gz = Flag("-z", "--gz", usage: "Decompress with GZip first")
    let bz2 = Flag("-j", "--bz2", usage: "Decompress with BZip2 first")
    let xz = Flag("-x", "--xz", usage: "Decompress with XZ first")

    let info = Flag("-i", "--info", usage: "Print list of entries in container and their attributes")
    let extract = Key<String>("-e", "--extract", usage: "Extract container into specified directory (it must be empty or not exist)")

    var optionGroups: [OptionGroup] {
        let compressions = OptionGroup(options: [gz, bz2, xz], restriction: .atMostOne)
        let actions = OptionGroup(options: [info, extract], restriction: .exactlyOne)
        return [compressions, actions]
    }

    let archive = Parameter()

    func execute() throws {
        var fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                        options: .mappedIfSafe)

        if gz.value {
            fileData = try GzipArchive.unarchive(archive: fileData)
        } else if bz2.value {
            fileData = try BZip2.decompress(data: fileData)
        } else if xz.value {
            fileData = try XZArchive.unarchive(archive: fileData)
        }

        if info.value {
            let entries = try TarContainer.open(container: fileData)
            swcomp.printInfo(entries)
        } else {
            let outputPath = self.extract.value ?? FileManager.default.currentDirectoryPath

            if try !isValidOutputDirectory(outputPath, create: true) {
                print("ERROR: Specified path already exists and is not a directory.")
                exit(1)
            }

            let entries = try TarContainer.open(container: fileData)
            try swcomp.write(entries, outputPath, verbose.value)
        }
    }

}
