// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class DeflateTests: XCTestCase {

    private static let testType: String = "deflate"

    func testTruncation() throws {
        // In this test we check that there is no crash when dealing with the truncation in the middle of the Deflate
        // compressed data. The idea is to take three different types of Deflate blocks (uncompressed, static Huffman,
        // and dynamic Huffman), truncate the input data manually at a random point inside it, and then test if an
        // appropriate error is thrown. To make test a bit more sophisticated we generate a number of random truncations
        // for each tested file.

        // test6 contains dynamic Huffman Deflate block.
        // test8 contains static Huffman Deflate block.
        // test9 contains uncompressed Deflate block.

        for testName in ["test6", "test8", "test9"] {
            let testData = try Constants.data(forTest: testName, withType: DeflateTests.testType)
            for _ in 0..<10 {
                let truncationIndex = Int.random(in: (testData.startIndex + 1)..<testData.endIndex)
                XCTAssertThrowsError(try Deflate.decompress(data: testData[..<truncationIndex]),
                                     "No error thrown, \(testName), truncationIndex=\(truncationIndex)")
            }
        }
    }

}
