//
//  Bzip2Tests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class Bzip2Tests: XCTestCase {

    static let testType: String = "bz2"

    func perform(test testName: String) {
        guard let testURL = Constants.url(forTest: testName, withType: Bzip2Tests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let decompressedData = try? BZip2.decompress(data: testData) else {
            XCTFail("Unable to decompress.")
            return
        }

        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get asnwer's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect.")

        #if PERF_TESTS
            print("Performing performance tests for \(Bzip2Tests.testType).\(testName)")
            self.measure {
                _ = try? BZip2.decompress(data: testData)
            }
        #endif
    }

    func testBzip2_1() {
        self.perform(test: "test1")
    }

    func testBzip2_2() {
        self.perform(test: "test2")
    }

    func testBzip2_3() {
        self.perform(test: "test3")
    }

    func testBzip2_4() {
        self.perform(test: "test4")
    }

    func testBzip2_5() {
        self.perform(test: "test5")
    }

    #if LONG_TESTS
    func testBzip2_6() {
        self.perform(test: "test6")
    }
    #endif

    #if LONG_TESTS
    func testBzip2_7() {
        self.perform(test: "test7")
    }
    #endif

    func testBzip2_8() {
        self.perform(test: "test8")
    }

    func testBzip2_9() {
        self.perform(test: "test9")
    }

}
