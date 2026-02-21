// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SwiftCLI

final class RemoveRunCommand: Command {

    let name = "remove-run"
    let shortDescription = "Removes run from the file"
    let longDescription = "Removes a run identified by UUID and any associated results from the specified file"

    @Param var runUUID: String
    @Param var path: String

    func execute() throws {
        var saveFile = try SaveFile.load(from: self.path)
        guard let uuid = UUID(uuidString: self.runUUID)
            else { swcompExit(.benchmarkBadUUID) }
        if saveFile.runs.contains(where: { $0.uuid == uuid} ) {
            saveFile.runs.removeAll(where: { $0.uuid == uuid })
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(saveFile)
            try data.write(to: URL(fileURLWithPath: path))
        } else {
            print("WARNING: Specified run UUID is not found in the file. No changes made.")
        }
    }

}
