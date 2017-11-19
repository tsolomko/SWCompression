// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class LzmaTests: XCTestCase {

    private static let testType: String = "lzma"

    func perform(test testName: String) throws {
        guard let testURL = Constants.url(forTest: testName, withType: LzmaTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let decompressedData = try LZMA.decompress(data: testData)

        guard let answerURL = Constants.url(forAnswer: "test8") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

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
