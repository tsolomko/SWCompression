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
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: XZTests.testType),
                                       options: .mappedIfSafe) else {
            XCTFail("Failed to load test archive")
            return
        }

        let decompressedData = try? XZArchive.unarchive(archiveData: testData)

        guard decompressedData != nil  else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")

        #if PERF_TESTS
            print("Performing performance tests for \(XZTests.testType).\(testName)")
            self.measure {
                _ = try? XZArchive.unarchive(archiveData: testData)
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
}
