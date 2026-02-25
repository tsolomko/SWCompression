// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class DeflateTests: XCTestCase {

    private static let testType: String = "deflate"

    func testDeflateTruncation() throws {
        // In this test we check that there is no crash when dealing with the truncation in the middle of the Deflate
        // compressed data. The idea is to take three different types of Deflate blocks (uncompressed, static Huffman,
        // and dynamic Huffman), truncate the input data manually at a random point inside it, and then test if an
        // appropriate error is thrown. To make test a bit more sophisticated we generate a number of random truncations
        // for each tested file.

        // This test file contains uncompressed Deflate block.
        var testData = try Constants.data(forTest: "test9", withType: DeflateTests.testType)
        for _ in 0..<100 {
            let truncationIndex = Int.random(in: 23..<testData.count - 8)
            var thrownError: Error? = nil
            XCTAssertThrowsError(try Deflate.decompress(data: testData[..<truncationIndex]),
                                 "No error thrown, test9, truncationIndex=\(truncationIndex)") { thrownError = $0 }
            if let error = thrownError {
                XCTAssertTrue(error is DeflateError, "Unexpected error type: \(type(of: thrownError)), " +
                              "test9, truncationIndex=\(truncationIndex)")
            }
        }

        // This test file contains static Huffman Deflate block.
        testData = try Constants.data(forTest: "test8", withType: DeflateTests.testType)
        for _ in 0..<10 {
            let truncationIndex = Int.random(in: 23..<testData.count - 8)
            var thrownError: Error? = nil
            XCTAssertThrowsError(try Deflate.decompress(data: testData[..<truncationIndex]),
                                 "No error thrown, test8, truncationIndex=\(truncationIndex)") { thrownError = $0 }
            if let error = thrownError {
                XCTAssertTrue(error is DeflateError, "Unexpected error type: \(type(of: thrownError)), " +
                              "test8, truncationIndex=\(truncationIndex)")
            }
        }

        // This test file contains dynamic Huffman Deflate block.
        testData = try Constants.data(forTest: "test6", withType: DeflateTests.testType)
        for _ in 0..<10 {
            let truncationIndex = Int.random(in: 23..<testData.count - 8)
            var thrownError: Error? = nil
            XCTAssertThrowsError(try Deflate.decompress(data: testData[..<truncationIndex]),
                                 "No error thrown, test6, truncationIndex=\(truncationIndex)") { thrownError = $0 }
            if let error = thrownError {
                XCTAssertTrue(error is DeflateError, "Unexpected error type: \(type(of: thrownError)), " +
                              "test6, truncationIndex=\(truncationIndex)")
            }
        }
    }

}
