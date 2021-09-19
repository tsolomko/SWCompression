// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class SevenZipCommand: ContainerCommand {

    typealias ContainerType = SevenZipContainer

    let name = "7z"
    let shortDescription = "Extracts a 7-Zip container"

    let info = Flag("-i", "--info", description: "Print the list of entries in a container and their attributes")
    let extract = Key<String>("-e", "--extract", description: "Extract a container into the specified directory")
    let verbose = Flag("-v", "--verbose", description: "Print the list of extracted files and directories.")

    let archive = Parameter()

}
