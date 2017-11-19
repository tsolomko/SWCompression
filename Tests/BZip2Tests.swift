// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class BZip2Tests: XCTestCase {

    private static let testType: String = "bz2"

    func perform(test testName: String) throws {
        guard let testURL = Constants.url(forTest: testName, withType: BZip2Tests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let decompressedData = try BZip2.decompress(data: testData)

        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get asnwer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")

        #if PERF_TESTS
            print("Performing performance tests for \(BZip2Tests.testType).\(testName)")
            self.measure {
                _ = try? BZip2.decompress(data: testData)
            }
        #endif
    }

    func test1BZip2() throws {
        try self.perform(test: "test1")
    }

    func test2BZip2() throws {
        try self.perform(test: "test2")
    }

    func test3BZip2() throws {
        try self.perform(test: "test3")
    }

    func test4BZip2() throws {
        try self.perform(test: "test4")
    }

    func test5BZip2() throws {
        try self.perform(test: "test5")
    }

    func test6BZip2() throws {
        try self.perform(test: "test6")
    }

    func test7BZip2() throws {
        try self.perform(test: "test7")
    }

    func test8BZip2() throws {
        try self.perform(test: "test8")
    }

    func test9BZip2() throws {
        try self.perform(test: "test9")
    }

}
