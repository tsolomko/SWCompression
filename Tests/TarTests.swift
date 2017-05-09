//
//  TarTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 05.05.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class TarTests: XCTestCase {

    static let testType: String = "tar"

    /// Tests container with test5.answer file.
    func test() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "test",
                                                                 withType: TarTests.testType),
                                       options: .mappedIfSafe) else {
                                        XCTFail("Failed to load test archive")
                                        return
        }

        guard let result = try? TarContainer.open(containerData: testData) else {
            XCTFail("Unable to parse TAR container.")
            return
        }

        guard let entry = result[0] as? TarEntry else {
            XCTFail("Unable to convert to TarEntry.")
            return
        }

        XCTAssertEqual(entry.name, "test5.answer")
        XCTAssertEqual(entry.data(), Data())
    }

}
