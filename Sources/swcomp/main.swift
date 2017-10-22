// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

CLI.setup(name: "swcomp",
          version: "3.4.0",
          description: """
                       swcomp - small command-line client for SWCompression framework.
                       Serves as an example of SWCompression usage.
                       """)
SwiftCLI.GlobalOptions.source(GlobalOptions.self)
CLI.register(commands: [XZCommand(),
                        LZMACommand(),
                        BZip2Command(),
                        CompressBZip2Command(),
                        GZipCommand(),
                        CompressGZipCommand(),
                        ZipCommand(),
                        TarCommand(),
                        SevenZipCommand()])
_ = CLI.go()
