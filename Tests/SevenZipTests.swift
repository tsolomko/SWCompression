// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class SevenZipTests: XCTestCase {

    static let testType: String = "7z"

    func test1() {
        guard let testURL = Constants.url(forTest: "test1", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let infos = try? SevenZipContainer.info(container: testData) else {
            XCTFail("Unable to open 7z archive.")
            return
        }
        print(infos)
    }

    func test2() {
        guard let testURL = Constants.url(forTest: "test2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let infos = try? SevenZipContainer.info(container: testData) else {
            XCTFail("Unable to open 7z archive.")
            return
        }
        print(infos)
    }

    func test3() {
        guard let testURL = Constants.url(forTest: "test3", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        guard let testData = try? Data(contentsOf: testURL, options: .mappedIfSafe) else {
            XCTFail("Unable to load test archive.")
            return
        }

        guard let infos = try? SevenZipContainer.info(container: testData) else {
            XCTFail("Unable to open 7z archive.")
            return
        }
        print(infos)
    }

}
