// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class LzmaTests: XCTestCase {

    private static let testType: String = "lzma"

    func perform(test testName: String) throws {
        guard let testData = Constants.data(forTest: testName, withType: LzmaTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let decompressedData = try LZMA.decompress(data: testData)

        guard let answerData = Constants.data(forAnswer: "test8") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")
    }

    func testLzma8() throws {
        try self.perform(test: "test8")
    }

    func testLzma9() throws {
        try self.perform(test: "test9")
    }

    func testLzma10() throws {
        try self.perform(test: "test10")
    }

    func testLzma11() throws {
        try self.perform(test: "test11")
    }

}
