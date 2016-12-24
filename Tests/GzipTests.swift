//
//  GzipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//
//
import XCTest
@testable import SWCompression

class GzipTests: XCTestCase {

    static let testType: String = "gz"

    func perform(test testName: String, answer answerServiceInfo: GzipArchive.ServiceInfo) {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? GzipArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testGzip1() {
        self.perform(test: "test1", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1477672923,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "test.txt",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzip2() {
        self.perform(test: "test2", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1479237057,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "test2.answer",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzip3() {
        self.perform(test: "test3", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1479237147,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "test3.answer",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzip4() {
        self.perform(test: "test4", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1477673662,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "secondtest.txt",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzip5() {
        self.perform(test: "test5", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1477764584,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "empty.txt",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzip6() {
        self.perform(test: "test6", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1479237483,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "test6.answer",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzip7() {
        self.perform(test: "test7", answer: GzipArchive.ServiceInfo(magic: 0x8b1f,
                                                                    method: 8,
                                                                    flags: 8,
                                                                    mtime: 1479559913,
                                                                    extraFlags: 0,
                                                                    osType: 3,
                                                                    fileName: "test7.answer",
                                                                    comment: "",
                                                                    crc: 0))
    }

    func testGzipFull() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "random_file", withType: GzipTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        let decompressedData = try? GzipArchive.unarchive(archiveData: testData)

        guard decompressedData != nil  else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: "random_file")) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")
    }

}
