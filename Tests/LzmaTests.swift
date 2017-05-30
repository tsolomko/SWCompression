//
//  LzmaTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 15.12.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class LzmaTests: XCTestCase {

    static let testType: String = "lzma"

    func perform(test testName: String) {
        guard let testURL = Constants.url(forTest: testName, withType: LzmaTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let decompressedData = try? LZMA.decompress(compressedData: testData) else {
            XCTFail("Unable to decompress.")
            return
        }

        guard let answerURL = Constants.url(forAnswer: "test8") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test answer.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")
    }

    func testLzma8() {
        self.perform(test: "test8")
    }

    func testLzma9() {
        self.perform(test: "test9")
    }

    func testLzma10() {
        self.perform(test: "test10")
    }

    func testLzma11() {
        self.perform(test: "test11")
    }

}
