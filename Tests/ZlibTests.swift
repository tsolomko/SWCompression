//
//  ZlibTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import XCTest
@testable import SWCompression

class ZlibTests: XCTestCase {

    static let testType: String = "zlib"

    func testZlib() {
        let testName = "test"
        guard let testData = try? Data(contentsOf: Constants.url(forTest: testName, withType: ZlibTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        guard let testServiceInfo = try? ZlibArchive.serviceInfo(archiveData: testData) else {
            XCTFail("Failed to get service info")
            return
        }

        let answerServiceInfo = ZlibArchive.ServiceInfo(compressionMethod: 8,
                                                        windowSize: 32768,
                                                        compressionLevel: .defaultAlgorithm)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

    func testZlibFull() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "random_file", withType: ZlibTests.testType)) else {
            XCTFail("Failed to load test archive")
            return
        }

        let decompressedData = try? ZlibArchive.unarchive(archiveData: testData)

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
