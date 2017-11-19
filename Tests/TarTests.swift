// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarTests: XCTestCase {

    private static let testType: String = "tar"

    func test() throws {
        guard let testData = Constants.data(forTest: "test", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let result = try TarContainer.open(container: testData)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].info.name, "test5.answer")
        XCTAssertEqual(result[0].info.size, 0)
        XCTAssertEqual(result[0].info.type, .regular)
        XCTAssertEqual(result[0].data, Data())
    }

    func testPax() throws {
        guard let testData = Constants.data(forTest: "full_test", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let result = try TarContainer.open(container: testData)

        XCTAssertEqual(result.count, 5)

        for entry in result {
            let name = entry.info.name.components(separatedBy: ".")[0]
            guard let answerData = Constants.data(forAnswer: name) else {
                XCTFail("Unable to get answer data.")
                return
            }

            XCTAssertEqual(entry.data, answerData)
            XCTAssertEqual(entry.info.type, .regular)
            XCTAssertNotNil(entry.info.accessTime)
        }
    }

    func testFormats() throws {
        let formatTestNames = ["test_gnu", "test_oldgnu", "test_pax", "test_ustar", "test_v7"]

        guard let answerData = Constants.data(forAnswer: "test1") else {
            XCTFail("Unable to get answer data.")
            return
        }

        for testName in formatTestNames {
            guard let testData = Constants.data(forTest: testName, withType: TarTests.testType) else {
                XCTFail("Unable to get test data.")
                return
            }
            let result = try TarContainer.open(container: testData)

            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result[0].info.name, "test1.answer")
            XCTAssertEqual(result[0].info.size, 14)
            XCTAssertEqual(result[0].info.type, .regular)
            XCTAssertEqual(result[0].data, answerData)
        }
    }

    func testLongNames() throws {
        let formatTestNames = ["long_test_gnu", "long_test_oldgnu", "long_test_pax"]

        for testName in formatTestNames {
            guard let testData = Constants.data(forTest: testName, withType: TarTests.testType) else {
                XCTFail("Unable to get test data.")
                return
            }
            let result = try TarContainer.open(container: testData)

            XCTAssertEqual(result.count, 6)
        }
    }

    func testWinContainer() throws {
        guard let testData = Constants.data(forTest: "test_win", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try TarContainer.open(container: testData)

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
        guard let testData = Constants.data(forTest: "test_empty_file", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        guard let testData = Constants.data(forTest: "test_empty_dir", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        guard let testData = Constants.data(forTest: "test_empty_cont", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

    func testBigContainer() throws {
        guard let testData = Constants.data(forTest: "SWCompressionSourceCode", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        #if LONG_TESTS
            _ = try TarContainer.open(container: testData)
        #else
            _ = try TarContainer.info(container: testData)
        #endif
    }

}
