// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

class CreateTar: BenchmarkCommand {

    let name = "create-tar"
    let shortDescription = "Tar container creation"

    let inputs = CollectedParameter()

    let benchmarkName = "TAR Create"
    let benchmarkFunction: ([TarEntry]) throws -> Any = TarContainer.create

    func loadInput(_ input: String) throws -> [TarEntry] {
        return try TarEntry.createEntries(input, false)
    }

}
