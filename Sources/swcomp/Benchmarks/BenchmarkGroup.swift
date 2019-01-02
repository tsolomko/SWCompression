// Copyright (c) 2019 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SwiftCLI

class BenchmarkGroup: CommandGroup {

    let name = "benchmark"
    let shortDescription = "Run specified benchmark using external files"

    let children: [Routable] = [UnGzip(), UnXz(), UnBz2(), InfoTar(), InfoZip(), Info7z(), CompDeflate(), CompBz2()]

}
