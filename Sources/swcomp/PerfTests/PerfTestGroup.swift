// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SwiftCLI

class PerfTestGroup: CommandGroup {

    let name = "perf-test"
    let shortDescription = "Commands for performance testing"

    let children: [Routable] = [UnGzip(), UnXz(), UnBz2(), InfoTar(), InfoZip(), Info7z(), CompDeflate(), CompBz2()]

}
