// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

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
        guard let testGzipHeader = try? GzipHeader(archive: testData) else {
            XCTFail("Unable to get archive header.")
            return
        }

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testGzipHeader.modificationTime, Date(timeIntervalSince1970: TimeInterval(mtime)),
                       "Incorrect mtime.")
        XCTAssertEqual(testGzipHeader.osType, .unix, "Incorrect OS type.")
        XCTAssertEqual(testGzipHeader.fileName, "\(testName).answer", "Incorrect original file name.")
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
        guard let decompressedData = try? GzipArchive.unarchive(archive: testData) else {
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
                _ = try? GzipArchive.unarchive(archive: testData)
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
        guard let testGzipHeader = try? GzipHeader(archive: archiveData) else {
            XCTFail("Unable to get archive header.")
            return
        }

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method.")
        XCTAssertEqual(testGzipHeader.modificationTime?.timeIntervalSince1970, mtime, "Incorrect mtime.")
        XCTAssertEqual(testGzipHeader.osType, .macintosh, "Incorrect OS type.")
        XCTAssertEqual(testGzipHeader.fileName, "\(testName).answer", "Incorrect original file name.")
        XCTAssertEqual(testGzipHeader.comment, "some file comment", "Incorrect comment.")
        XCTAssertTrue(testGzipHeader.isTextFile)

        // Test output GZip archive content.
        guard let decompressedData = try? GzipArchive.unarchive(archive: archiveData) else {
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

    func testMultiUnarchive() {
        guard let testURL = Constants.url(forTest: "test_multi", withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let members = try? GzipArchive.multiUnarchive(archive: testData) else {
            XCTFail("Unable to unarchive.")
            return
        }

        XCTAssertEqual(members.count, 4)

        for i in 1...4 {
            let header = members[i - 1].header
            XCTAssertEqual(header.fileName, "test\(i).answer")
            let data = members[i - 1].data

            guard let answerURL = Constants.url(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
                XCTFail("Unable to load answer.")
                return
            }

            XCTAssertEqual(data, answerData)
        }
    }

    func testMultiUnarchiveRedundant() {
        guard let testURL = Constants.url(forTest: "test1", withType: GzipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let members = try? GzipArchive.multiUnarchive(archive: testData) else {
            XCTFail("Unable to unarchive.")
            return
        }

        XCTAssertEqual(members.count, 1)

        let header = members[0].header
        XCTAssertEqual(header.fileName, "test1.answer")
        let data = members[0].data

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(data, answerData)
    }

}
