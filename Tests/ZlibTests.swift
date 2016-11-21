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
                                                        compressionLevel: .defaultAlgorithm,
                                                        startPoint: 2)

        XCTAssertEqual(testServiceInfo, answerServiceInfo, "Incorrect service info")
    }

}
