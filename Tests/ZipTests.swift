// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    private static let testType: String = "zip"

    func testBigContainer() throws {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            _ = try ZipContainer.open(container: testData)
        #else
            _ = try ZipContainer.info(container: testData)
        #endif
    }

    func testZip64() throws {
        guard let testURL = Constants.url(forTest: "TestZip64", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)
    }

    func testDataDescriptor() throws {
        guard let testURL = Constants.url(forTest: "TestDataDescriptor", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)
    }

    func testUnicode() throws {
        guard let testURL = Constants.url(forTest: "TestUnicode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "текстовый файл")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertNotNil(entries[0].data)
    }

    func testZipLZMA() throws {
        guard let testURL = Constants.url(forTest: "test_zip_lzma", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testZipBZip2() throws {
        guard let testURL = Constants.url(forTest: "test_zip_bzip2", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testWinContainer() throws {
        guard let testURL = Constants.url(forTest: "test_win", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].info.name, "dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, nil)

        XCTAssertEqual(entries[1].info.name, "text_win.txt")
        XCTAssertEqual(entries[1].info.type, .regular)
        XCTAssertEqual(entries[1].info.size, 15)
        XCTAssertEqual(entries[1].data, "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        guard let testURL = Constants.url(forTest: "test_empty_file", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        guard let testURL = Constants.url(forTest: "test_empty_dir", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, nil)
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
