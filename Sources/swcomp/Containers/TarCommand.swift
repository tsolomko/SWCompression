// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class TarCommand: Command {

    let name = "tar"
    let shortDescription = "Extracts TAR container"

    let gz = Flag("-z", "--gz", description: "Decompress with GZip first")
    let bz2 = Flag("-j", "--bz2", description: "Decompress with BZip2 first")
    let xz = Flag("-x", "--xz", description: "Decompress with XZ first")

    let info = Flag("-i", "--info", description: "Print list of entries in container and their attributes")
    let extract = Key<String>("-e", "--extract", description: "Extract container into specified directory")
    let format = Flag("-f", "--format", description: "Prints \"format\" of the container")

    let verbose = Flag("--verbose", description: "Print the list of extracted files and directories.")

    var optionGroups: [OptionGroup] {
        let compressions = OptionGroup(options: [gz, bz2, xz], restriction: .atMostOne)
        let actions = OptionGroup(options: [info, extract, format], restriction: .exactlyOne)
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
            let entries = try TarContainer.info(container: fileData)
            swcomp.printInfo(entries)
        } else if let outputPath = self.extract.value {
            if try !isValidOutputDirectory(outputPath, create: true) {
                print("ERROR: Specified path already exists and is not a directory.")
                exit(1)
            }

            let entries = try TarContainer.open(container: fileData)
            try swcomp.write(entries, outputPath, verbose.value)
        } else if format.value {
            let format = try TarContainer.formatOf(container: fileData)
            switch format {
            case .prePosix:
                print("TAR format: pre-POSIX")
            case .ustar:
                print("TAR format: POSIX aka \"ustar\"")
            case .gnu:
                print("TAR format: POSIX with GNU extensions")
            case .pax:
                print("TAR format: PAX")
            }
            
        }
    }

}
