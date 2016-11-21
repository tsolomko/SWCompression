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

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1477672923,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 19,
                                                        fileName: "test.txt",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testGzip2() {
        let testName = "test2"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1479237057,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 23,
                                                        fileName: "test2.answer",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testGzip3() {
        let testName = "test3"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1479237147,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 23,
                                                        fileName: "test3.answer",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testGzip4() {
        let testName = "test4"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1477673662,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 25,
                                                        fileName: "secondtest.txt",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }


    func testGzip5() {
        let testName = "test5"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1477764584,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 20,
                                                        fileName: "empty.txt",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testGzip6() {
        let testName = "test6"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1479237483,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 23,
                                                        fileName: "test6.answer",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testGzip7() {
        let testName = "test7"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = GzipArchive.ServiceInfo(magic: [31, 139],
                                                        method: 8,
                                                        flags: 8,
                                                        mtime: 1479559913,
                                                        extraFlags: 0,
                                                        osType: 3,
                                                        startPoint: 23,
                                                        fileName: "test7.answer",
                                                        comment: "",
                                                        crc: 0)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }


}
