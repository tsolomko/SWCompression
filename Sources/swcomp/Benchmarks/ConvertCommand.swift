// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SwiftCLI

final class ConvertCommand: Command {

    let name = "convert"
    let shortDescription = "Converts save file to a new format"
    let longDescription = "Converts specified with saved benchmark results to a new format"

    @Param var path: String

    func execute() throws {
        let oldSaveFile = try OldSaveFile.load(from: self.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(SaveFile(oldSaveFile))
        try data.write(to: URL(fileURLWithPath: path))
    }

}
