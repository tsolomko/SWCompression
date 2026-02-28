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

    func testSymbol16First() throws {
        // Symbol 16 cannot be the first symbol encoding code lengths in the dynamic Huffman block. Previously, there
        // was a crash in such situation. This test checks that error is thrown appropriately.

        // The input data was constructed manually:
        // - 101: last block bit and dynamical Huffman block type,
        // - 00000: minimal amount of literal codes,
        // - 00000: minimal amount of distances codes,
        // - 0000: minimal amount of code length codes (4),
        // - 011 011 010 001: four code lenghts for code length codes (1, 2, 3, 3),
        // - 0: encoded code length symbol 16 (which means to copy previous code length).
        let testData = Data([0b0000_0101, 0b0000_0000, 0b1010_0010, 0b0000_1101])
        XCTAssertThrowsError(try Deflate.decompress(data: testData))
    }

    func testCodeLengthsOverCopy() throws {
        // Previously, when decoding code lengths in a dynamic Huffman block if a copy code length count was
        // sufficiently large, it could lead to an inconsistent state or a crash (due to out-of-range array subscript).
        // In the new version these situations are checked.

        // Repeat a zero code length too many times. The input data was constructed manually:
        // - 101: last block bit and dynamical Huffman block type,
        // - 00000: minimal amount of literal codes,
        // - 00000: minimal amount of distances codes,
        // - 0000: minimal amount of code length codes (4),
        // - 011 011 010 001: four code lenghts for code length codes (1, 2, 3, 3),
        // - 111: encoded code length symbol 18 (which means to repeat 0 code length),
        // - 1111111: maximum repeat amount,
        // - 111: encoded code length symbol 18 (which means to repeat 0 code length),
        // - 1111111: maximum repeat amount.
        var testData = Data([0b0000_0101, 0b0000_0000, 0b1010_0010, 0b1110_1101, 0b1111_1111, 0b1111_1111, 0b0000_0001])
        XCTAssertThrowsError(try Deflate.decompress(data: testData))

        // Copy a previous code length too many times. The input data was constructed manually:
        // - 101: last block bit and dynamical Huffman block type,
        // - 00000: minimal amount of literal codes,
        // - 00000: minimal amount of distances codes,
        // - 0000: minimal amount of code length codes (4),
        // - 011 011 010 001: four code lenghts for code length codes (1, 2, 3, 3),
        // - 111: encoded code length symbol 18 (which means to repeat 0 code length),
        // - 1111111: maximum repeat amount,
        // - 111: encoded code length symbol 18 (which means to repeat 0 code length),
        // - 1101100 repeat amount.
        // - 0: encoded code length symbol 16 (which means to copy a previous code length),
        // - 01: copy amount.
        testData = Data([0b0000_0101, 0b0000_0000, 0b1010_0010, 0b1110_1101, 0b1111_1111, 0b1011_0011, 0b0000_0101])
        XCTAssertThrowsError(try Deflate.decompress(data: testData))
    }

}
