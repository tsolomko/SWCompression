// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

extension GzipHeader: CustomStringConvertible {

    public var description: String {
        var output = ""
        output += "File name: \(self.fileName ?? "")\n"
        output += "File system type: \(self.osType)\n"
        output += "Compression method: \(self.compressionMethod)\n"
        if let mtime = self.modificationTime {
            output += "Modification time: \(mtime)\n"
        }
        if let comment = self.comment {
            output += "Comment: \(comment)\n"
        }
        output += "Is text file: \(self.isTextFile)"
        return output
    }

}
