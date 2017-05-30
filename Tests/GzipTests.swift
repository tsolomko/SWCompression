//
//  GzipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class GzipTests: XCTestCase {

    static let testType: String = "gz"

    func header(test testName: String, mtime: Int) {
        // Load archive.
        guard let testURL = Constants.url(forTest: testName, withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        // Test GZip header parsing
        guard let testGzipHeader = try? GzipHeader(archiveData: testData) else {
            XCTFail("Unable to get archive header.")
            return
        }

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testGzipHeader.modificationTime, Date(timeIntervalSince1970: TimeInterval(mtime)),
                       "Incorrect mtime.")
        XCTAssertEqual(testGzipHeader.osType, .unix, "Incorrect OS type.")
        XCTAssertEqual(testGzipHeader.originalFileName, "\(testName).answer", "Incorrect original file name.")
        XCTAssertEqual(testGzipHeader.comment, nil, "Incorrect comment.")
    }

    func unarchive(test testName: String) {
        // Load archive.
        guard let testURL = Constants.url(forTest: testName, withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        // Test GZip unarchiving.
        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
            XCTFail("Unable to decompress.")
            return
        }

        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")

        #if PERF_TESTS
            print("Performing performance tests for gz.\(testName)")
            self.measure {
                _ = try? GzipArchive.unarchive(archiveData: archiveData)
            }
        #endif
    }

    func archive(test testName: String) {
        // Load answer data.
        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer archive.")
            return
        }

        // Options for archiving.
        let mtimeDate = Date(timeIntervalSinceNow: 0.0)
        let mtime = Double(Int(mtimeDate.timeIntervalSince1970))

        // Test GZip archiving.
        guard let archiveData = try? GzipArchive.archive(data: answerData,
                                                         comment: "some file comment",
                                                         fileName: testName + ".answer",
                                                         writeHeaderCRC: true,
                                                         isTextFile: true,
                                                         osType: .macintosh,
                                                         modificationTime: mtimeDate) else {
            XCTFail("Unable to create archive.")
            return
        }

        // Test output GZip header.
        guard let testGzipHeader = try? GzipHeader(archiveData: archiveData) else {
            XCTFail("Unable to get archive header.")
            return
        }

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testGzipHeader.modificationTime?.timeIntervalSince1970, mtime, "Incorrect mtime.")
        XCTAssertEqual(testGzipHeader.osType, .macintosh, "Incorrect OS type.")
        XCTAssertEqual(testGzipHeader.originalFileName, "\(testName).answer", "Incorrect original file name.")
        XCTAssertEqual(testGzipHeader.comment, "some file comment", "Incorrect comment.")
        XCTAssertTrue(testGzipHeader.isTextFile)

        // Test output GZip archive content.
        guard let decompressedData = try? GzipArchive.unarchive(archiveData: archiveData) else {
            XCTFail("Unable to decompress.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")
    }

    func testGzip1() {
        self.header(test: "test1", mtime: 1482698300)
        self.unarchive(test: "test1")
    }

    func testGzip2() {
        self.header(test: "test2", mtime: 1482698300)
        self.unarchive(test: "test2")
    }

    func testGzip3() {
        self.header(test: "test3", mtime: 1482698301)
        self.unarchive(test: "test3")
    }

    func testGzip4() {
        self.header(test: "test4", mtime: 1482698301)
        self.unarchive(test: "test4")
    }

    func testGzip5() {
        self.header(test: "test5", mtime: 1482698242)
        self.unarchive(test: "test5")
    }

    func testGzip6() {
        self.header(test: "test6", mtime: 1482698305)
        self.unarchive(test: "test6")
    }

    func testGzip7() {
        self.header(test: "test7", mtime: 1482698304)
        self.unarchive(test: "test7")
    }

    func testGzip8() {
        self.header(test: "test8", mtime: 1483040005)
        self.unarchive(test: "test8")
    }

    func testGzip9() {
        self.header(test: "test9", mtime: 1483040005)
        self.unarchive(test: "test9")
    }

    func testGzipArchive4() {
        self.archive(test: "test4")
    }

}
