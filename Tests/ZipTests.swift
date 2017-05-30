//
//  ZipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.01.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    static let testType: String = "zip"

    func test() {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let zipDict = try? ZipContainer.open(containerData: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard zipDict.count == 211 else {
            XCTFail("Incorrect number of entries.")
            return
        }
    }

    func testZip64() {
        guard let testURL = Constants.url(forTest: "TestZip64", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(containerData: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 6 else {
            XCTFail("Incorrect number of entries.")
            return
        }
    }

    func testDataDescriptor() {
        guard let testURL = Constants.url(forTest: "TestDataDescriptor", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(containerData: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 6 else {
            XCTFail("Incorrect number of entries.")
            return
        }

        for entry in entries where !entry.isDirectory {
            XCTAssertNotNil(try? entry.data())
        }
    }

    func testUnicode() {
        guard let testURL = Constants.url(forTest: "TestUnicode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let entries = try? ZipContainer.open(containerData: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }

        guard entries.count == 1 else {
            XCTFail("Incorrect number of entries.")
            return
        }

        XCTAssertEqual(entries[0].name, "текстовый файл")
        XCTAssertEqual(entries[0].isDirectory, false)
    }

}
