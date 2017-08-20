// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZlibTests: XCTestCase {

    static let testType: String = "zlib"

    func testZlib() throws {
        let testName = "test"

        guard let testURL = Constants.url(forTest: testName, withType: ZlibTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let testZlibHeader = try ZlibHeader(archive: testData)

        XCTAssertEqual(testZlibHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testZlibHeader.compressionLevel, .defaultAlgorithm, "Incorrect compression level.")
        XCTAssertEqual(testZlibHeader.windowSize, 32768, "Incorrect window size.")
    }

    func testZlibFull() throws {
        guard let testURL = Constants.url(forTest: "random_file", withType: ZlibTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let decompressedData = try ZlibArchive.unarchive(archive: testData)

        guard let answerURL = Constants.url(forAnswer: "test9") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(decompressedData, answerData, "Unarchiving was incorrect")
    }

    func testCreateZlib() throws {
        guard let testURL = Constants.url(forAnswer: "test9") else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let archiveData = try ZlibArchive.archive(data: testData)
        let reextractedData = try ZlibArchive.unarchive(archive: archiveData)

        XCTAssertEqual(testData, reextractedData, "Re-extracted data is not equal to initial data.")
    }

}
