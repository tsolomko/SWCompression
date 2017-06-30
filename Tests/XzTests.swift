//
//  XzTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 18.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class XZTests: XCTestCase {

    static let testType: String = "xz"

    func perform(test testName: String) {
        guard let testURL = Constants.url(forTest: testName, withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let decompressedData = try? XZArchive.unarchive(archive: testData) else {
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
            print("Performing performance tests for \(XZTests.testType).\(testName)")
            self.measure {
                _ = try? XZArchive.unarchive(archive: testData)
            }
        #endif
    }

    func testXz1() {
        self.perform(test: "test1")
    }

    func testXz2() {
        self.perform(test: "test2")
    }

    func testXz3() {
        self.perform(test: "test3")
    }

    func testXz4() {
        // This test contains padding!
        self.perform(test: "test4")
    }

    func testXz5() {
        self.perform(test: "test5")
    }

    func testXz6() {
        self.perform(test: "test6")
    }

    func testXz7() {
        self.perform(test: "test7")
    }

    func testXz8() {
        self.perform(test: "test8")
    }

    func testXz9() {
        self.perform(test: "test9")
    }

    func testMultiUnarchive() {
        // Doesn't contain any padding.
        guard let testURL = Constants.url(forTest: "test_multi", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let members = try? XZArchive.multiUnarchive(archive: testData) else {
            XCTFail("Unable to unarchive.")
            return
        }

        XCTAssertEqual(members.count, 4)

        for i in 1...4 {
            guard let answerURL = Constants.url(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
                XCTFail("Unable to load answer.")
                return
            }

            XCTAssertEqual(members[i - 1], answerData)
        }
    }

    func testMultiUnarchiveWithPadding() {
        // After first stream - no padding.
        // After second - 4 bytes of padding.
        // Third - 8 bytes.
        // At the end - 4 bytes.

        guard let testURL = Constants.url(forTest: "test_multi_pad", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let members = try? XZArchive.multiUnarchive(archive: testData) else {
            XCTFail("Unable to unarchive.")
            return
        }

        XCTAssertEqual(members.count, 4)

        for i in 1...4 {
            guard let answerURL = Constants.url(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer's URL.")
                return
            }

            guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
                XCTFail("Unable to load answer.")
                return
            }

            XCTAssertEqual(members[i - 1], answerData)
        }
    }

    func testMultiUnarchiveRedundant1() {
        guard let testURL = Constants.url(forTest: "test4", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let members = try? XZArchive.multiUnarchive(archive: testData) else {
            XCTFail("Unable to unarchive.")
            return
        }

        XCTAssertEqual(members.count, 1)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(members[0], answerData)
    }

    func testMultiUnarchiveRedundant2() {
        guard let testURL = Constants.url(forTest: "test1", withType: XZTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let members = try? XZArchive.multiUnarchive(archive: testData) else {
            XCTFail("Unable to unarchive.")
            return
        }

        XCTAssertEqual(members.count, 1)

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load answer.")
            return
        }

        XCTAssertEqual(members[0], answerData)
    }

}
