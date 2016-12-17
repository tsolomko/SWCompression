//
//  LzmaTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class LzmaTests: XCTestCase {

    static let testType: String = "lzma"

    func perform(test testName: String) {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: LzmaTests.testType),
                                       options: .mappedIfSafe) else {
                                        XCTFail("Failed to load test archive")
                                        return
        }

        guard let decompressedData = try? LZMA.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")

        #if PERF_TESTS
            print("Performing performance tests for \(LzmaTests.testType).\(testName)")
            self.measure {
                let _ = try? LZMA.decompress(compressedData: testData)
            }
        #endif
    }

    func testLzma8() {
        self.perform(test: "test8")
    }

    func testLzma9() {
        self.perform(test: "test9")
    }

    func testLzma10() {
        self.perform(test: "test10")
    }

    func testLzm11() {
        self.perform(test: "test11")
    }

}
