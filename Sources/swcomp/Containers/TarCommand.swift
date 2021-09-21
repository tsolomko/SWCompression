// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class TarCommand: Command {

    let name = "tar"
    let shortDescription = "Extracts a TAR container"

    let gz = Flag("-z", "--gz", description: "Decompress with GZip first")
    let bz2 = Flag("-j", "--bz2", description: "Decompress with BZip2 first")
    let xz = Flag("-x", "--xz", description: "Decompress with XZ first")

    let info = Flag("-i", "--info", description: "Print the list of entries in a container and their attributes")
    let extract = Key<String>("-e", "--extract", description: "Extract a container into specified directory")
    let format = Flag("-f", "--format", description: "Print the \"format\" of a container")
    let create = Key<String>("-c", "--create",
                             description: "Create a new container containing the specified file/directory (recursively)")

    let verbose = Flag("-v", "--verbose", description: "Print the list of extracted files and directories.")

    var optionGroups: [OptionGroup] {
        let compressions = OptionGroup(options: [gz, bz2, xz], restriction: .atMostOne)
        let actions = OptionGroup(options: [info, extract, format, create], restriction: .exactlyOne)
        return [compressions, actions]
    }

    let archive = Parameter()

    func execute() throws {
        var fileData: Data
        if self.create.value == nil {
            fileData = try Data(contentsOf: URL(fileURLWithPath: self.archive.value),
                                    options: .mappedIfSafe)

            if gz.value {
                fileData = try GzipArchive.unarchive(archive: fileData)
            } else if bz2.value {
                fileData = try BZip2.decompress(data: fileData)
            } else if xz.value {
                fileData = try XZArchive.unarchive(archive: fileData)
            }
        } else {
            fileData = Data()
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
        } else if let inputPath = self.create.value {
            let fileManager = FileManager.default

            guard !fileManager.fileExists(atPath: self.archive.value) else {
                print("ERROR: Output path already exists.")
                exit(1)
            }

            if gz.value || bz2.value || xz.value {
                print("Warning: compression options are unsupported and ignored when creating new container.")
            }

            guard fileManager.fileExists(atPath: inputPath) else {
                print("ERROR: Specified path doesn't exist.")
                exit(1)
            }
            if verbose.value {
                print("Creating new container at \"\(self.archive.value)\" from \"\(inputPath)\"")
                print("d = directory, f = file, l = symbolic link")
            }
            let entries = try TarEntry.createEntries(inputPath, verbose.value)
            let containerData = TarContainer.create(from: entries)
            try containerData.write(to: URL(fileURLWithPath: self.archive.value))
        }
    }

}
