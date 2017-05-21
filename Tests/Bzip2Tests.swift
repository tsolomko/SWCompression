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
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName,
                                                                 withType: Bzip2Tests.testType),
                                       options: .mappedIfSafe) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? BZip2.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")

        #if PERF_TESTS
            print("Performing performance tests for \(Bzip2Tests.testType).\(testName)")
            self.measure {
                _ = try? BZip2.decompress(compressedData: testData)
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

    func testBzip2_6() {
        self.perform(test: "test6")
    }

//    func testBzip2_7() {
//        self.perform(test: "test7")
//    }

    func testBzip2_8() {
        self.perform(test: "test8")
    }

    func testBzip2_9() {
        self.perform(test: "test9")
    }

}
