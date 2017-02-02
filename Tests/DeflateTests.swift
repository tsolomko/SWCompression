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

    func perform(test testName: String) {
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
            print("Performing performance tests for \(DeflateTests.testType).\(testName)")
            self.measure {
                _ = try? Deflate.decompress(compressedData: testData)
            }
        #endif
    }

    func testDeflate1() {
        self.perform(test: "test1")
    }

    func testDeflate2() {
        self.perform(test: "test2")
    }

    func testDeflate3() {
        self.perform(test: "test3")
    }

    func testDeflate4() {
        self.perform(test: "test4")
    }

    func testDeflate5() {
        self.perform(test: "test5")
    }

    func testDeflate6() {
        self.perform(test: "test6")
    }

    func testDeflate7() {
        self.perform(test: "test7")
    }

    func testLengthEncode() {
        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: "test4")) else {
            XCTFail("Failed to get the answer")
            return
        }

//        print(String(data: answerData, encoding: .utf8)!)

        let answerBytes = answerData.toArray(type: UInt8.self)

        print(answerBytes.count)

        let compBytes = Deflate.lengthEncode(answerBytes)

        print(compBytes)
        print(compBytes.count)
    }

}
