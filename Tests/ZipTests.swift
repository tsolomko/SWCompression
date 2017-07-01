// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    static let testType: String = "zip"

    func test() {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(container: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 211 else {
            XCTFail("Incorrect number of entries.")
            return
        }
    }

    func testZip64() {
        guard let testURL = Constants.url(forTest: "TestZip64", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(container: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 6 else {
            XCTFail("Incorrect number of entries.")
            return
        }
    }

    func testDataDescriptor() {
        guard let testURL = Constants.url(forTest: "TestDataDescriptor", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(container: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 6 else {
            XCTFail("Incorrect number of entries.")
            return
        }

        for entry in entries where !entry.isDirectory {
            XCTAssertNotNil(try? entry.data())
        }
    }

    func testUnicode() {
        guard let testURL = Constants.url(forTest: "TestUnicode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(container: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 1 else {
            XCTFail("Incorrect number of entries.")
            return
        }

        XCTAssertEqual(entries[0].name, "текстовый файл")
        XCTAssertEqual(entries[0].isDirectory, false)
    }

    func testZipLZMA() {
        guard let testURL = Constants.url(forTest: "test_zip_lzma", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(container: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 1 else {
            XCTFail("Incorrect number of entries.")
            return
        }

        XCTAssertEqual(entries[0].name, "test4.answer")
        XCTAssertEqual(entries[0].isDirectory, false)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(try? entries[0].data(), answerData)
    }

}
