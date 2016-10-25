//
//  SWCompressionTests.swift
//  SWCompressionTests
//
//  Created by Timofey Solomko on 16.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import XCTest
@testable import SWCompression

class SWCompressionTests: XCTestCase {

    func testDeflate() {
        let testData = try? Data(contentsOf: Constants.testArchivePath)
        XCTAssertNotNil(testData, "Failed to load test archive")
        XCTAssertNotNil(try? Deflate.decompress(data: testData!), "Failed to decompress")
    }

}
