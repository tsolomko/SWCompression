//
//  DataWithPointerTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 04.11.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import XCTest
@testable import SWCompression

class DataWithPointerTests: XCTestCase {

    func testDataWithPointer() {
        self.measure {
            let testData = try? Data(contentsOf: Constants.relativelyBigFilePath)
            XCTAssertNotNil(testData, "Failed to load test archive")
            let testDataWithPointer = DataWithPointer(data: testData!)
            for _ in 0..<testData!.count {
                let _ = testDataWithPointer.bits(count: 8)
            }
        }
    }

    func testData() {
        self.measure {
            let testData = try? Data(contentsOf: Constants.relativelyBigFilePath)
            XCTAssertNotNil(testData, "Failed to load test archive")
            var index = 0
            for _ in 0..<testData!.count  {
                let start = (index, 0)
                let end = (index, 7)
                index += 1
                let _ = testData!.bits(from: start, to: end)
            }
        }
    }

}
