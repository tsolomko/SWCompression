// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

struct GlobalOptions: GlobalOptionsSource {
    static let verbose = Flag("--verbose", usage: "Print the list of extracted files and directories.")
    static var options: [Option] {
        return [verbose]
    }
}

extension ZipCommand {
    var verbose: Flag {
        return GlobalOptions.verbose
    }
}

extension TarCommand {
    var verbose: Flag {
        return GlobalOptions.verbose
    }
}

extension SevenZipCommand {
    var verbose: Flag {
        return GlobalOptions.verbose
    }
}
