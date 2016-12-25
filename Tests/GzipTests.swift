//
//  GzipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class GzipTests: XCTestCase {

    static let testType: String = "gz"

    func perform(test testName: String, mtime: Date, originalFileName: String) {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName,
                                                                 withType: GzipTests.testType),
                                       options: .mappedIfSafe) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testGzipHeader = try? GzipHeader(archiveData: testData) else {
            XCTFail("Failed to get archive header")
            return
        }

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method")
        XCTAssertEqual(testGzipHeader.modificationTime, mtime, "Incorrect mtime")
        XCTAssertEqual(testGzipHeader.osType, .unix, "Incorrect os type")
        XCTAssertEqual(testGzipHeader.originalFileName, originalFileName, "Incorrect original file name")
        XCTAssertEqual(testGzipHeader.comment, nil, "Incorrect comment")
    }

    func testGzip1() {
        self.perform(test: "test1",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1477672923)),
                     originalFileName: "test.txt")
    }

    func testGzip2() {
        self.perform(test: "test2",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1479237057)),
                     originalFileName: "test2.answer")
    }

    func testGzip3() {
        self.perform(test: "test3",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1479237147)),
                     originalFileName: "test3.answer")
    }

    func testGzip4() {
        self.perform(test: "test4",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1477673662)),
                     originalFileName: "secondtest.txt")
    }

    func testGzip5() {
        self.perform(test: "test5",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1477764584)),
                     originalFileName: "empty.txt")
    }

    func testGzip6() {
        self.perform(test: "test6",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1479237483)),
                     originalFileName: "test6.answer")
    }

    func testGzip7() {
        self.perform(test: "test7",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1479559913)),
                     originalFileName: "test7.answer")
    }

    func testGzipFull() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "random_file",
                                                                 withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        let decompressedData = try? GzipArchive.unarchive(archiveData: testData)

        guard decompressedData != nil  else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: "random_file")) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

}
