// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

/* TODO: Switch to usage of Bundle.allBundles() function of Foundation framework when it becomes implemented.*/
// Version constants:
let SWCompressionVersion = "3.4.0"
let swcompRevision = "88"

CLI.setup(name: "swcomp",
          version: "\(swcompRevision), SWCompression version: \(SWCompressionVersion)",
          description: "swcomp - small command-line client for SWCompression framework.")
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
