// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class XZTests: XCTestCase {

    private static let testType: String = "xz"

    func perform(test testName: String) throws {
        guard let testData = Constants.data(forTest: testName, withType: XZTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let decompressedData = try XZArchive.unarchive(archive: testData)

        guard let answerData = Constants.data(forAnswer: testName) else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")
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

    func testMultiStreamNoPadding() throws {
        // Doesn't contain any padding.
        guard let testData = Constants.data(forTest: "test_multi", withType: XZTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let decompressedData = try XZArchive.unarchive(archive: testData)
        let splitDecompressedData = try XZArchive.splitUnarchive(archive: testData)

        var answerData = Data()
        for i in 1...4 {
            guard let currentAnswerData = Constants.data(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer data.")
                return
            }

            answerData.append(currentAnswerData)
            XCTAssertEqual(splitDecompressedData[i - 1], currentAnswerData)
        }

        XCTAssertEqual(decompressedData, answerData)
    }

    func testMultiStreamComplexPadding() throws {
        // After first stream - no padding.
        // After second - 4 bytes of padding.
        // Third - 8 bytes.
        // At the end - 4 bytes.

        guard let testData = Constants.data(forTest: "test_multi_pad", withType: XZTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let decompressedData = try XZArchive.unarchive(archive: testData)
        let splitDecompressedData = try XZArchive.splitUnarchive(archive: testData)

        var answerData = Data()
        for i in 1...4 {
            guard let currentAnswerData = Constants.data(forAnswer: "test\(i)") else {
                XCTFail("Unable to get answer data.")
                return
            }

            answerData.append(currentAnswerData)
            XCTAssertEqual(splitDecompressedData[i - 1], currentAnswerData)
        }

        XCTAssertEqual(decompressedData, answerData)
    }

}
