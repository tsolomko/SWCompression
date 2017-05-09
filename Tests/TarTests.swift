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

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "test5.answer")
        XCTAssertEqual(result[0].size, 0)
        XCTAssertEqual(result[0].isDirectory, false)
        XCTAssertEqual(try? result[0].data(), Data())
    }

}
