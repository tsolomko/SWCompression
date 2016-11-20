//
//  PerformanceTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 01.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class PerformanceTests: XCTestCase {

    func testPerformance() {
        self.measure {
            let testData = try? Data(contentsOf: Constants.relativelyBigFilePath)
            XCTAssertNotNil(testData, "Failed to load test archive")
            let decompressedData = try? GzipArchive.unarchive(archiveData: testData!)
            XCTAssertNotNil(decompressedData, "Failed to decompress")
        }
    }

}
