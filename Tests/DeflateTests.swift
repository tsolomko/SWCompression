// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class DeflateTests: XCTestCase {

    func perform(compressionTest testName: String) throws {
        guard let answerURL = Constants.url(forAnswer: testName) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)
        let deflatedData = try Deflate.compress(data: answerData)
        let reUncompData = try Deflate.decompress(data: deflatedData)

        XCTAssertEqual(answerData, reUncompData,
                       "Data before compression and after decompression of compressed data aren't equal.")

        #if PERF_TESTS
            print("Performing performance tests for deflate.\(testName)")
            self.measure {
                _ = try? Deflate.compress(data: answerData)
            }
        #endif

    }

    func testDeflate1() throws {
        try self.perform(compressionTest: "test1")
    }

    func testDeflate2() throws {
        try self.perform(compressionTest: "test2")
    }

    func testDeflate3() throws {
        try self.perform(compressionTest: "test3")
    }

    func testDeflate4() throws {
        try self.perform(compressionTest: "test4")
    }

    func testDeflate5() throws {
        try self.perform(compressionTest: "test5")
    }

    func testDeflate6() throws {
        try self.perform(compressionTest: "test6")
    }

    #if LONG_TESTS

    func testDeflate7() throws {
        try self.perform(compressionTest: "test7")
    }

    #endif

    func testDeflate8() throws {
        try self.perform(compressionTest: "test8")
    }

    func testDeflate9() throws {
        try self.perform(compressionTest: "test9")
    }

}
