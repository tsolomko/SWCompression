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

    func test() {
        guard let testData = try? Data(contentsOf: Constants.url(forTest: "test", withType: TarTests.testType),
                                       options: .mappedIfSafe) else {
                                        XCTFail("Failed to load test archive")
                                        return
        }

        _ = try? TarContainer.files(from: testData)
    }

}
