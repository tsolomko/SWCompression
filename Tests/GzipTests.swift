// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class GzipTests: XCTestCase {

    private static let testType: String = "gz"

    func header(test testName: String, mtime: Int) throws {
        guard let testURL = Constants.url(forTest: testName, withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let testGzipHeader = try GzipHeader(archive: testData)

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testGzipHeader.modificationTime, Date(timeIntervalSince1970: TimeInterval(mtime)),
                       "Incorrect mtime.")
        XCTAssertEqual(testGzipHeader.osType, .unix, "Incorrect OS type.")
        XCTAssertEqual(testGzipHeader.fileName, "\(testName).answer", "Incorrect original file name.")
        XCTAssertEqual(testGzipHeader.comment, nil, "Incorrect comment.")
    }

    func unarchive(test testName: String) throws {
        guard let testURL = Constants.url(forTest: testName, withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let decompressedData = try? GzipArchive.unarchive(archive: testData)

        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")

        #if PERF_TESTS
            print("Performing performance tests for gz.\(testName)")
            self.measure {
                _ = try? GzipArchive.unarchive(archive: testData)
            }
        #endif
    }

    func archive(test testName: String) throws {
        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        // Options for archiving.
        let mtimeDate = Date(timeIntervalSinceNow: 0.0)
        let mtime = Double(Int(mtimeDate.timeIntervalSince1970))

        // Test GZip archiving.
        let archiveData = try GzipArchive.archive(data: answerData, comment: "some file comment",
                                                  fileName: testName + ".answer",
                                                  writeHeaderCRC: true,
                                                  isTextFile: true,
                                                  osType: .macintosh,
                                                  modificationTime: mtimeDate)

        // Test output GZip header.
        let testGzipHeader = try GzipHeader(archive: archiveData)

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testGzipHeader.modificationTime?.timeIntervalSince1970, mtime, "Incorrect mtime.")
        XCTAssertEqual(testGzipHeader.osType, .macintosh, "Incorrect OS type.")
        XCTAssertEqual(testGzipHeader.fileName, "\(testName).answer", "Incorrect original file name.")
        XCTAssertEqual(testGzipHeader.comment, "some file comment", "Incorrect comment.")
        XCTAssertTrue(testGzipHeader.isTextFile)

        // Test output GZip archive content.
        let decompressedData = try GzipArchive.unarchive(archive: archiveData)

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")
    }

    func testGzip1() throws {
        try self.header(test: "test1", mtime: 1482698300)
        try self.unarchive(test: "test1")
    }

    func testGzip2() throws {
        try self.header(test: "test2", mtime: 1482698300)
        try self.unarchive(test: "test2")
    }

    func testGzip3() throws {
        try self.header(test: "test3", mtime: 1482698301)
        try self.unarchive(test: "test3")
    }

    func testGzip4() throws {
        try self.header(test: "test4", mtime: 1482698301)
        try self.unarchive(test: "test4")
    }

    func testGzip5() throws {
        try self.header(test: "test5", mtime: 1482698242)
        try self.unarchive(test: "test5")
    }

    func testGzip6() throws {
        try self.header(test: "test6", mtime: 1482698305)
        try self.unarchive(test: "test6")
    }

    func testGzip7() throws {
        try self.header(test: "test7", mtime: 1482698304)
        try self.unarchive(test: "test7")
    }

    func testGzip8() throws {
        try self.header(test: "test8", mtime: 1483040005)
        try self.unarchive(test: "test8")
    }

    func testGzip9() throws {
        try self.header(test: "test9", mtime: 1483040005)
        try self.unarchive(test: "test9")
    }

    func testGzipArchive4() throws {
        try self.archive(test: "test4")
    }

    func testMultiUnarchive() throws {
        guard let testURL = Constants.url(forTest: "test_multi", withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let members = try GzipArchive.multiUnarchive(archive: testData)

        XCTAssertEqual(members.count, 4)

        for i in 1...4 {
            let header = members[i - 1].header
            XCTAssertEqual(header.fileName, "test\(i).answer")
            let data = members[i - 1].data

            guard let answerURL = Constants.url(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

            XCTAssertEqual(data, answerData)
        }
    }

    func testMultiUnarchiveRedundant() throws {
        guard let testURL = Constants.url(forTest: "test1", withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let members = try GzipArchive.multiUnarchive(archive: testData)

        XCTAssertEqual(members.count, 1)

        let header = members[0].header
        XCTAssertEqual(header.fileName, "test1.answer")
        let data = members[0].data

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(data, answerData)
    }

}
