// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class Bzip2Tests: XCTestCase {

    static let testType: String = "bz2"

    func perform(test testName: String) {
        guard let testURL = Constants.url(forTest: testName, withType: Bzip2Tests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let decompressedData = try? BZip2.decompress(data: testData) else {
            XCTFail("Unable to decompress.")
            return
        }

        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get asnwer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")

        #if PERF_TESTS
            print("Performing performance tests for \(Bzip2Tests.testType).\(testName)")
            self.measure {
                _ = try? BZip2.decompress(data: testData)
            }
        #endif
    }

    func test1Bzip2() {
        self.perform(test: "test1")
    }

    func test2Bzip2() {
        self.perform(test: "test2")
    }

    func test3Bzip2() {
        self.perform(test: "test3")
    }

    func test4Bzip2() {
        self.perform(test: "test4")
    }

    func test5Bzip2() {
        self.perform(test: "test5")
    }

    #if LONG_TESTS

    func test6Bzip2() {
        self.perform(test: "test6")
    }

    func test7Bzip2() {
        self.perform(test: "test7")
    }

    #endif

    func test8Bzip2() {
        self.perform(test: "test8")
    }

    func test9Bzip2() {
        self.perform(test: "test9")
    }

}
