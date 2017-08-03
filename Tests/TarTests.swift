// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarTests: XCTestCase {

    static let testType: String = "tar"

    func test() throws {
        guard let testURL = Constants.url(forTest: "test", withType: TarTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let result = try TarContainer.open(container: testData)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test5.answer")
        XCTAssertEqual(result[0].size, 0)
        XCTAssertEqual(result[0].isDirectory, false)
        XCTAssertEqual(try result[0].data(), Data())
    }

    func testPax() throws {
        guard let testURL = Constants.url(forTest: "full_test", withType: TarTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let result = try TarContainer.open(container: testData)

        XCTAssertEqual(result.count, 5)

        for entry in result {
            guard let tarEntry = entry as? TarEntry else {
                XCTFail("Unable to convert entry to TarEntry.")
                return
            }
            let name = tarEntry.name.components(separatedBy: ".")[0]
            guard let answerURL = Constants.url(forAnswer: name) else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

            XCTAssertEqual(tarEntry.data(), answerData)
            XCTAssertEqual(tarEntry.isDirectory, false)
            XCTAssertNotNil(tarEntry.accessTime)
        }
    }

    func testFormats() throws {
        let formatTestNames = ["test_gnu", "test_oldgnu", "test_pax", "test_ustar", "test_v7"]

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        for testName in formatTestNames {
            guard let testURL = Constants.url(forTest: testName, withType: TarTests.testType) else {
                XCTFail("Unable to get test's URL.")
                return
            }

            let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
            let result = try TarContainer.open(container: testData)

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result[0].name, "test1.answer")
            XCTAssertEqual(result[0].size, 14)
            XCTAssertEqual(result[0].isDirectory, false)
            XCTAssertEqual(try result[0].data(), answerData)
        }
    }

    func testLongNames() throws {
        let formatTestNames = ["long_test_gnu", "long_test_oldgnu", "long_test_pax"]

        for testName in formatTestNames {
            guard let testURL = Constants.url(forTest: testName, withType: TarTests.testType) else {
                XCTFail("Unable to get test's URL.")
                return
            }

            let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
            let result = try TarContainer.open(container: testData)

            XCTAssertEqual(result.count, 6)
        }
    }

    func testWinContainer() throws {
        guard let testURL = Constants.url(forTest: "test_win", withType: TarTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try TarContainer.open(container: testData)

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
        guard let testURL = Constants.url(forTest: "test_empty_file", withType: TarTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "empty_file")
        XCTAssertEqual(entries[0].isDirectory, false)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())
    }

    func testEmptyDirectory() throws {
        guard let testURL = Constants.url(forTest: "test_empty_dir", withType: TarTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "empty_dir/")
        XCTAssertEqual(entries[0].isDirectory, true)
        XCTAssertEqual(entries[0].size, 0)
        XCTAssertEqual(try entries[0].data(), Data())
    }

    func testEmptyContainer() throws {
        guard let testURL = Constants.url(forTest: "test_empty_cont", withType: TarTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try TarContainer.open(container: testData)
        
        XCTAssertEqual(entries.isEmpty, true)
    }

}
