// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class BZip2Tests: XCTestCase {

    private static let testType: String = "bz2"

    func perform(test testName: String) throws {
        guard let testData = Constants.data(forTest: testName, withType: BZip2Tests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let decompressedData = try BZip2.decompress(data: testData)

        guard let answerData = Constants.data(forAnswer: testName) else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")
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
