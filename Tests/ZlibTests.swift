//
//  ZlibTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class ZlibTests: XCTestCase {

    static let testType: String = "zlib"

    func testZlib() {
        let testName = "test"

        guard let testURL = Constants.url(forTest: testName, withType: ZlibTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let testZlibHeader = try? ZlibHeader(archiveData: testData) else {
            XCTFail("Unable to get archive header.")
            return
        }

        XCTAssertEqual(testZlibHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testZlibHeader.compressionLevel, .defaultAlgorithm, "Incorrect compression level.")
        XCTAssertEqual(testZlibHeader.windowSize, 32768, "Incorrect window size.")
    }

    func testZlibFull() {
        guard let testURL = Constants.url(forTest: "random_file", withType: ZlibTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        let decompressedData = try? ZlibArchive.unarchive(archive: testData)

        guard decompressedData != nil  else {
            XCTFail("Unable to decompress.")
            return
        }

        guard let answerURL = Constants.url(forAnswer: "test9") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Unarchiving was incorrect")
    }

    func testCreateZlib() {
        guard let testURL = Constants.url(forAnswer: "test9") else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let archiveData = try? ZlibArchive.archive(data: testData) else {
            XCTFail("Unable to create archive.")
            return
        }

        guard let reextractedData = try? ZlibArchive.unarchive(archive: archiveData) else {
            XCTFail("Unable to re-extract created archive.")
            return
        }

        XCTAssertEqual(testData, reextractedData, "Re-extracted data is not equal to initial data.")
    }

}
