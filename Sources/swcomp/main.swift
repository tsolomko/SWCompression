// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

let cli = CLI(name: "swcomp", version: "4.5.7",
              description: """
                           swcomp - a small command-line client for SWCompression framework.
                           Serves as an example of SWCompression usage.
                           """)
cli.commands = [XZCommand(),
                LZMACommand(),
                BZip2Command(),
                GZipCommand(),
                ZipCommand(),
                TarCommand(),
                SevenZipCommand(),
                BenchmarkGroup()]
cli.goAndExit()
