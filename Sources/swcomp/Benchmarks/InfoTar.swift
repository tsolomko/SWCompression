// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression
import SwiftCLI

#if os(Linux)
    import CoreFoundation
#endif

class InfoTar: Command {

    let name = "info-tar"
    let shortDescription = "Performs benchmarking of TAR info function using specified files"

    let files = CollectedParameter()

    func execute() throws {
        print("TAR info function Benchmark")
        print("===========================")

        for file in self.files.value {
            print("File: \(file)\n")

            let inputURL = URL(fileURLWithPath: file)
            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)

            var totalTime: Double = 0

            var maxTime = Double(Int.min)
            var minTime = Double(Int.max)

            for i in 1...10 {
                print("Iteration \(i): ", terminator: "")
                let startTime = CFAbsoluteTimeGetCurrent()
                _ = try TarContainer.info(container: fileData)
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print(String(format: "%.3f", timeElapsed))
                totalTime += timeElapsed
                if timeElapsed > maxTime {
                    maxTime = timeElapsed
                }
                if timeElapsed < minTime {
                    minTime = timeElapsed
                }
            }
            print(String(format: "\nAverage time: %.3f \u{B1} %.3f", totalTime / 10, (maxTime - minTime) / 2))
            print("-------------------------------------")
        }
    }

}
