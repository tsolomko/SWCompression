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

class CompBz2: Command {

    let name = "comp-bz2"
    let shortDescription = "Performs performance testing for BZip2 compression using specified files"

    let files = CollectedParameter()

    func execute() throws {
        print("BZip2 Compression Performance Testing")
        print("===================================")

        for file in self.files.value {
            print("File: \(file)\n")

            let inputURL = URL(fileURLWithPath: file)
            let fileData = try Data(contentsOf: inputURL, options: .mappedIfSafe)

            var totalTime: Double = 0

            var maxTime = Double(Int.min)
            var minTime = Double(Int.max)

            for i in 1...6 {
                print("Iteration \(i): ", terminator: "")
                let startTime = CFAbsoluteTimeGetCurrent()
                _ = BZip2.compress(data: fileData)
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
            print(String(format: "\nAverage time: %.3f \u{B1} %.3f", totalTime / 6, (maxTime - minTime) / 2))
            print("-----------------------------------")
        }
    }

}
