// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZlibTests: XCTestCase {

    private static let testType: String = "zlib"

    func testZlib() throws {
        let testName = "test"

        guard let testData = Constants.data(forTest: testName, withType: ZlibTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let testZlibHeader = try ZlibHeader(archive: testData)

        XCTAssertEqual(testZlibHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testZlibHeader.compressionLevel, .defaultAlgorithm, "Incorrect compression level.")
        XCTAssertEqual(testZlibHeader.windowSize, 32768, "Incorrect window size.")
    }

    func testZlibFull() throws {
        guard let testData = Constants.data(forTest: "random_file", withType: ZlibTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let decompressedData = try ZlibArchive.unarchive(archive: testData)

        guard let answerData = Constants.data(forAnswer: "test9") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Unarchiving was incorrect")
    }

    func testCreateZlib() throws {
        guard let testData = Constants.data(forAnswer: "test9") else {
            XCTFail("Unable to get answer data.")
            return
        }
        let archiveData = ZlibArchive.archive(data: testData)
        let reextractedData = try ZlibArchive.unarchive(archive: archiveData)

        XCTAssertEqual(testData, reextractedData, "Re-extracted data is not equal to initial data.")
    }

}
