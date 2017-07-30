// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class SevenZipTests: XCTestCase {

    static let testType: String = "7z"

    func testEmptyFile() throws {
        guard let testURL = Constants.url(forTest: "test_empty_file", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "empty_file")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())
    }

    func testEmptyDirectory() throws {
        guard let testURL = Constants.url(forTest: "test_empty_dir", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "empty_dir")
        XCTAssertEqual(entries[0].isDirectory, true)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())
    }

    func testEmptyContainer() throws {
        guard let testURL = Constants.url(forTest: "test_empty_cont", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

    func test1() throws {
        guard let testURL = Constants.url(forTest: "test1", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "test1.answer")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, answerData.count)
        XCTAssertEqual(try entries[0].data(), answerData)
    }

    func test2() throws {
        guard let testURL = Constants.url(forTest: "test2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        guard let answer1URL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        var answerData = try Data(contentsOf: answer1URL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].name, "test1.answer")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, answerData.count)
        XCTAssertEqual(try entries[0].data(), answerData)

        guard let answer4URL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        answerData = try Data(contentsOf: answer4URL, options: .mappedIfSafe)

        XCTAssertEqual(entries[1].name, "test4.answer")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[1].size, answerData.count)
        XCTAssertEqual(try entries[1].data(), answerData)
    }

    func test3() throws {
        guard let testURL = Constants.url(forTest: "test3", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            _ = try SevenZipContainer.open(container: testData)
        #else
            _ = try SevenZipContainer.info(container: testData)
        #endif
    }

    func testBigContainer() throws {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            _ = try SevenZipContainer.open(container: testData)
        #else
            _ = try SevenZipContainer.info(container: testData)
        #endif
    }

}
