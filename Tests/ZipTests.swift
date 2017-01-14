//
//  ZipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.01.17.
//  Copyright © 2017 tsolomko. All rights reserved.
//

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    static let testType: String = "zip"

    func test() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "SWCompressionSourceCode", withType: ZipTests.testType),
                                       options: .mappedIfSafe) else {
                                        XCTFail("Failed to load test archive")
                                        return
        }

        guard let zipContainer = try? ZipContainer.open(containerData: testData) else {
            XCTFail("Unable to open ZIP archive.")
            return
        }
    }

}
