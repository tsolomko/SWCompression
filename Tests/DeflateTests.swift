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

    static let testType: String = "deflate"

    func perform(decompressionTest testName: String) {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType),
                                       options: .mappedIfSafe) else {
            XCTFail("Failed to load test archive")
            return
        }

        let decompressedData = try? Deflate.decompress(compressedData: testData)

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
            print("Performing performance tests for un\(DeflateTests.testType).\(testName)")
            self.measure {
                _ = try? Deflate.decompress(compressedData: testData)
            }
        #endif
    }

    func perform(compressionTest testName: String) {
        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        guard let deflatedData = try? Deflate.compress(data: answerData) else {
            XCTFail("Unable to deflate data")
            return
        }

        let reUncompData = try! Deflate.decompress(compressedData: deflatedData)
        XCTAssertEqual(answerData, reUncompData,
                       "Data before compression and after decompression of compressed data aren't equal")

        #if PERF_TESTS
            print("Performing performance tests for \(DeflateTests.testType).\(testName)")
            self.measure {
                _ = try? Deflate.compress(data: answerData)
            }
        #endif

    }

    func testUnDeflate1() {
        self.perform(decompressionTest: "test1")
    }

    func testUnDeflate2() {
        self.perform(decompressionTest: "test2")
    }

    func testUnDeflate3() {
        self.perform(decompressionTest: "test3")
    }

    func testUnDeflate4() {
        self.perform(decompressionTest: "test4")
    }

    func testUnDeflate5() {
        self.perform(decompressionTest: "test5")
    }

    func testUnDeflate6() {
        self.perform(decompressionTest: "test6")
    }

    func testUnDeflate7() {
        self.perform(decompressionTest: "test7")
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

    func testDeflate7() {
        self.perform(compressionTest: "test7")
    }

}
