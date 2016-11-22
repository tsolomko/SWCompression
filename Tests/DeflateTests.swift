//
//  DeflateTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 21.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class DeflateTests: XCTestCase {

    static let testType: String = "deflate"

    func testDeflate1() {
        let testName = "test1"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testDeflate2() {
        let testName = "test2"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testDeflate3() {
        let testName = "test3"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }


    func testDeflate4() {
        let testName = "test4"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }


    func testDeflate5() {
        let testName = "test5"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }


    func testDeflate6() {
        let testName = "test6"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }


    func testDeflate7() {
        let testName = "test7"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: DeflateTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? Deflate.decompress(compressedData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

}
