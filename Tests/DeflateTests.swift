//
//  DeflateTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 21.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class DeflateTests: XCTestCase {

    func perform(compressionTest testName: String) {
        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let deflatedData = try? Deflate.compress(data: answerData) else {
            XCTFail("Unable to deflate data")
            return
        }

        guard let reUncompData = try? Deflate.decompress(data: deflatedData) else {
            XCTFail("Unable to re-decompress data.")
            return
        }

        XCTAssertEqual(answerData, reUncompData,
                       "Data before compression and after decompression of compressed data aren't equal.")

        #if PERF_TESTS
            print("Performing performance tests for deflate.\(testName)")
            self.measure {
                _ = try? Deflate.compress(data: answerData)
            }
        #endif

    }

    func testDeflate1() {
        self.perform(compressionTest: "test1")
    }

    func testDeflate2() {
        self.perform(compressionTest: "test2")
    }

    func testDeflate3() {
        self.perform(compressionTest: "test3")
    }

    func testDeflate4() {
        self.perform(compressionTest: "test4")
    }

    func testDeflate5() {
        self.perform(compressionTest: "test5")
    }

    func testDeflate6() {
        self.perform(compressionTest: "test6")
    }

    #if LONG_TESTS
    func testDeflate7() {
        self.perform(compressionTest: "test7")
    }
    #endif

    func testDeflate8() {
        self.perform(compressionTest: "test8")
    }

    func testDeflate9() {
        self.perform(compressionTest: "test9")
    }

}
