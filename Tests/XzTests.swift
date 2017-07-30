// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class XZTests: XCTestCase {

    static let testType: String = "xz"

    func perform(test testName: String) throws {
        guard let testURL = Constants.url(forTest: testName, withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let decompressedData = try XZArchive.unarchive(archive: testData)

        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")

        #if PERF_TESTS
            print("Performing performance tests for \(XZTests.testType).\(testName)")
            self.measure {
                _ = try XZArchive.unarchive(archive: testData)
            }
        #endif
    }

    func testXz1() throws {
        try self.perform(test: "test1")
    }

    func testXz2() throws {
        try self.perform(test: "test2")
    }

    func testXz3() throws {
        try self.perform(test: "test3")
    }

    func testXz4() throws {
        // This test contains padding!
        try self.perform(test: "test4")
    }

    func testXz5() throws {
        try self.perform(test: "test5")
    }

    func testXz6() throws {
        try self.perform(test: "test6")
    }

    func testXz7() throws {
        try self.perform(test: "test7")
    }

    func testXz8() throws {
        try self.perform(test: "test8")
    }

    func testXz9() throws {
        try self.perform(test: "test9")
    }

    func testMultiUnarchive() throws {
        // Doesn't contain any padding.
        guard let testURL = Constants.url(forTest: "test_multi", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let members = try XZArchive.multiUnarchive(archive: testData)

        XCTAssertEqual(members.count, 4)

        for i in 1...4 {
            guard let answerURL = Constants.url(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

            XCTAssertEqual(members[i - 1], answerData)
        }
    }

    func testMultiUnarchiveWithPadding() throws {
        // After first stream - no padding.
        // After second - 4 bytes of padding.
        // Third - 8 bytes.
        // At the end - 4 bytes.

        guard let testURL = Constants.url(forTest: "test_multi_pad", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let members = try XZArchive.multiUnarchive(archive: testData)

        XCTAssertEqual(members.count, 4)

        for i in 1...4 {
            guard let answerURL = Constants.url(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

            XCTAssertEqual(members[i - 1], answerData)
        }
    }

    func testMultiUnarchiveRedundant1() throws {
        guard let testURL = Constants.url(forTest: "test4", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let members = try XZArchive.multiUnarchive(archive: testData)

        XCTAssertEqual(members.count, 1)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(members[0], answerData)
    }

    func testMultiUnarchiveRedundant2() throws {
        guard let testURL = Constants.url(forTest: "test1", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let members = try XZArchive.multiUnarchive(archive: testData)

        XCTAssertEqual(members.count, 1)

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(members[0], answerData)
    }

}
