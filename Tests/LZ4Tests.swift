// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class LZ4Tests: XCTestCase {

    private static let testType: String = "lz4"

    // These tests test frames with independent blocks (since they all have only one block). The frames also have
    // additional features enabled, such as content size and block checksums.

    func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: LZ4Tests.testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: testName)
        XCTAssertEqual(decompressedData, answerData)
    }

    func test1LZ4() throws {
        try self.perform(test: "test1")
    }

    func test2LZ4() throws {
        try self.perform(test: "test2")
    }

    func test3LZ4() throws {
        try self.perform(test: "test3")
    }

    func test4LZ4() throws {
        try self.perform(test: "test4")
    }

    func test5LZ4() throws {
        try self.perform(test: "test5")
    }

    func test6LZ4() throws {
        try self.perform(test: "test6")
    }

    func test7LZ4() throws {
        try self.perform(test: "test7")
    }

    func test8LZ4() throws {
        try self.perform(test: "test8")
    }

    func test9LZ4() throws {
        try self.perform(test: "test9")
    }

    func testDependentBlocks() throws {
        // This test contains dependent blocks (with the size of 64 kB), as well as has additional features enabled,
        // such as content size and block checksums.
        let testData = try Constants.data(forTest: "SWCompressionSourceCode.tar", withType: LZ4Tests.testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        XCTAssertEqual(decompressedData, answerData)
    }

}
