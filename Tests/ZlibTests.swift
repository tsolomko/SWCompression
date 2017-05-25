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
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName,
                                                                 withType: ZlibTests.testType),
                                       options: .mappedIfSafe) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testZlibHeader = try? ZlibHeader(archiveData: testData) else {
            XCTFail("Failed to get archive header")
            return
        }

        XCTAssertEqual(testZlibHeader.compressionMethod, .deflate, "Incorrect compression method")
        XCTAssertEqual(testZlibHeader.compressionLevel, .defaultAlgorithm, "Incorrect compression level")
        XCTAssertEqual(testZlibHeader.windowSize, 32768, "Incorrect window size")
    }

    func testZlibFull() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "random_file",
                                                                 withType: ZlibTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        let decompressedData = try? ZlibArchive.unarchive(archiveData: testData)

        guard decompressedData != nil  else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: "test9")) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testCreateZlib() {
        guard let testData = try? Data(contentsOf: Constants.url(forAnswer: "test9"),
                                       options: .mappedIfSafe) else {
                                        XCTFail("Failed to load test data.")
                                        return
        }

        guard let archiveData = try? ZlibArchive.archive(data: testData, options: []) else {
            XCTFail("Unable to create archive.")
            return
        }

        guard let reextractedData = try? ZlibArchive.unarchive(archiveData: archiveData) else {
            XCTFail("Unable to re-extract created archive.")
            return
        }

        XCTAssertEqual(testData, reextractedData, "Re-extracted data is not equal to initial data.")
    }

}
