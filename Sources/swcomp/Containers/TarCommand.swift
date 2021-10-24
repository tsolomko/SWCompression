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

    @Flag("-z", "--gz", description: "Decompress with GZip first")
    var gz: Bool

    @Flag("-j", "--bz2", description: "Decompress with BZip2 first")
    var bz2: Bool

    @Flag("-x", "--xz", description: "Decompress with XZ first")
    var xz: Bool

    @Flag("-i", "--info", description: "Print the list of entries in a container and their attributes")
    var info: Bool

    @Key("-e", "--extract", description: "Extract a container into specified directory")
    var extract: String?

    @Flag("-f", "--format", description: "Print the \"format\" of a container")
    var format: Bool

    @Key("-c", "--create", description: "Create a new container containing the specified file/directory (recursively)")
    var create: String?

    @Flag("-v", "--verbose", description: "Print the list of extracted files and directories.")
    var verbose: Bool

    var optionGroups: [OptionGroup] {
        return [.atMostOne($gz, $bz2, $xz), .exactlyOne($info, $extract, $format, $create)]
    }

    @Param var input: String

    func execute() throws {
        var fileData: Data
        if self.create == nil {
            fileData = try Data(contentsOf: URL(fileURLWithPath: self.input),
                                    options: .mappedIfSafe)

            if gz {
                fileData = try GzipArchive.unarchive(archive: fileData)
            } else if bz2 {
                fileData = try BZip2.decompress(data: fileData)
            } else if xz {
                fileData = try XZArchive.unarchive(archive: fileData)
            }
        } else {
            fileData = Data()
        }

        if info {
            let entries = try TarContainer.info(container: fileData)
            swcomp.printInfo(entries)
        } else if let outputPath = self.extract {
            if try !isValidOutputDirectory(outputPath, create: true) {
                print("ERROR: Specified path already exists and is not a directory.")
                exit(1)
            }

            let entries = try TarContainer.open(container: fileData)
            try swcomp.write(entries, outputPath, verbose)
        } else if format {
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
        } else if let inputPath = self.create {
            let fileManager = FileManager.default

            guard !fileManager.fileExists(atPath: self.input) else {
                print("ERROR: Output path already exists.")
                exit(1)
            }

            if gz || bz2 || xz {
                print("Warning: compression options are unsupported and ignored when creating new container.")
            }

            guard fileManager.fileExists(atPath: inputPath) else {
                print("ERROR: Specified path doesn't exist.")
                exit(1)
            }
            if verbose {
                print("Creating new container at \"\(self.input)\" from \"\(inputPath)\"")
                print("d = directory, f = file, l = symbolic link")
            }
            let entries = try TarEntry.createEntries(inputPath, verbose)
            let containerData = TarContainer.create(from: entries)
            try containerData.write(to: URL(fileURLWithPath: self.input))
        }
    }

}
