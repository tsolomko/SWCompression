// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class DeflateCompressionTests: XCTestCase {

    func perform(compressionTest testName: String) throws {
        guard let answerData = Constants.data(forAnswer: testName) else {
            XCTFail("Unable to get answer data.")
            return
        }

        let compressedData = Deflate.compress(data: answerData)

        if testName != "test5" { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print("BZip2.CompressionRatio.test(\(testName))=\(compressionRatio)")
        } else {
            print("No compression ratio for test5.")
        }

        let reUncompData = try Deflate.decompress(data: compressedData)
        XCTAssertEqual(answerData, reUncompData)

        #if PERF_TESTS
            print("Performing performance tests for deflate.\(testName)")
            self.measure {
                _ = Deflate.compress(data: answerData)
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

    func testDeflate7() throws {
        try self.perform(compressionTest: "test7")
    }

    func testDeflate8() throws {
        try self.perform(compressionTest: "test8")
    }

    func testDeflate9() throws {
        try self.perform(compressionTest: "test9")
    }

}
