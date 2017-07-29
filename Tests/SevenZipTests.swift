// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class SevenZipTests: XCTestCase {

    static let testType: String = "7z"

    func test1() {
        guard let testURL = Constants.url(forTest: "test1", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? SevenZipContainer.open(container: testData) else {
            XCTFail("Unable to open 7z archive.")
            return
        }

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "test1.answer")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, answerData.count)
        XCTAssertEqual(try? entries[0].data(), answerData)
    }

    func test2() {
        guard let testURL = Constants.url(forTest: "test2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? SevenZipContainer.open(container: testData) else {
            XCTFail("Unable to open 7z archive.")
            return
        }

        XCTAssertEqual(entries.count, 2)

        guard let answer1URL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answer1Data = try? Data(contentsOf: answer1URL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(entries[0].name, "test1.answer")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, answer1Data.count)
        XCTAssertEqual(try? entries[0].data(), answer1Data)


        guard let answer4URL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answer4Data = try? Data(contentsOf: answer4URL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(entries[0].name, "test4.answer")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, answer4Data.count)
        XCTAssertEqual(try? entries[0].data(), answer4Data)
    }

    func test3() {
        guard let testURL = Constants.url(forTest: "test3", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        #if LONG_TESTS
            XCTAssertNotNil(try? SevenZipContainer.open(container: testData))
        #else
            XCTAssertNotNil(try? SevenZipContainer.info(container: testData))
        #endif
    }

    func testBigContainer() {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        #if LONG_TESTS
            XCTAssertNotNil(try? SevenZipContainer.open(container: testData))
        #else
            XCTAssertNotNil(try? SevenZipContainer.info(container: testData))
        #endif
    }

}
