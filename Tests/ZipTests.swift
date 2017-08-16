// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    static let testType: String = "zip"

    func testBigContainer() throws {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 211)

        #if LONG_TESTS
            for entry in entries {
                _ = try entry.data()
            }
        #endif
    }

    func testMultiThreading() throws {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 211)

        for entry in entries {
            DispatchQueue.global(qos: .userInitiated).async {
                XCTAssertNotNil(try? entry.data())
            }
        }
    }

    func testZip64() throws {
        guard let testURL = Constants.url(forTest: "TestZip64", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            _ = try entry.data()
        }
    }

    func testDataDescriptor() throws {
        guard let testURL = Constants.url(forTest: "TestDataDescriptor", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            _ = try entry.data()
        }
    }

    func testUnicode() throws {
        guard let testURL = Constants.url(forTest: "TestUnicode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "текстовый файл")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertNotNil(try entries[0].data())
    }

    func testZipLZMA() throws {
        guard let testURL = Constants.url(forTest: "test_zip_lzma", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "test4.answer")
        XCTAssertEqual(entries[0].isDirectory, false)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(try entries[0].data(), answerData)
        // Test repeat of getting entry data (there was a problem with it).
        XCTAssertEqual(try entries[0].data(), answerData)
    }

    func testZipBZip2() throws {
        guard let testURL = Constants.url(forTest: "test_zip_bzip2", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "test4.answer")
        XCTAssertEqual(entries[0].isDirectory, false)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(try entries[0].data(), answerData)
    }

    func testWinContainer() throws {
        guard let testURL = Constants.url(forTest: "test_win", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].name, "dir/")
        XCTAssertEqual(entries[0].isDirectory, true)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())

        XCTAssertEqual(entries[1].name, "text_win.txt")
        XCTAssertEqual(entries[1].isDirectory, false)
        XCTAssertEqual(entries[1].size, 15)
        XCTAssertEqual(try entries[1].data(), "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        guard let testURL = Constants.url(forTest: "test_empty_file", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "empty_file")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())
    }

    func testEmptyDirectory() throws {
        guard let testURL = Constants.url(forTest: "test_empty_dir", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "empty_dir/")
        XCTAssertEqual(entries[0].isDirectory, true)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())
    }

    func testEmptyContainer() throws {
        guard let testURL = Constants.url(forTest: "test_empty_cont", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

}
