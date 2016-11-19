//
//  GzipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import XCTest
@testable import SWCompression

class GzipTests: XCTestCase {

    static let testType: String = "gz"

    func testGzip1() {
        let testName = "test1"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testGzip2() {
        let testName = "test2"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testGzip3() {
        let testName = "test3"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testGzip4() {
        let testName = "test4"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

    func testGzip5() {
        let testName = "test5"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

//    func testGzip6() {
//        let testName = "test6"
//        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
//            XCTFail("Failed to load test archive")
//            return
//        }
//
//        guard let decompressedData = try? GzipArchive.unarchive(archiveData: testData) else {
//            XCTFail("Failed to decompress")
//            return
//        }
//
//        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
//            XCTFail("Failed to get the answer")
//            return
//        }
//
//        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
//    }

}
