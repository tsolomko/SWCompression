// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class LZ4CompressionTests: XCTestCase {

    private static let testType: String = "lz4"

    func answerTest(_ testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)

        let compressedData = LZ4.compress(data: answerData)

        if testName != "test5" { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print("LZ4.\(testName).compressionRatio = \(compressionRatio)")
        } else {
            print("No compression ratio for test5.")
        }

        let redecompressedData = try LZ4.decompress(data: compressedData)
        XCTAssertEqual(redecompressedData, answerData)
    }

    func stringTest(_ string: String) throws {
        let answerData = Data(string.utf8)

        let compressedData = LZ4.compress(data: answerData)

        let redecompressedData = try LZ4.decompress(data: compressedData)
        XCTAssertEqual(redecompressedData, answerData)
    }

    func testLZ4CompressStrings() throws {
        try stringTest("banana")
        try stringTest("abaaba")
        try stringTest("abracadabra")
        try stringTest("cabbage")
        try stringTest("baabaabac")
        try stringTest("AAAAAAABBBBCCCD")
        try stringTest("AAAAAAA")
        try stringTest("qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890")
    }

    func testLZ4CompressBytes() throws {
        var bytes = ""
        for i: UInt8 in 0...255 {
            bytes += String(format: "%c", i)
        }
        try stringTest(bytes)
    }

    func testWithAnswer1LZ4Compress() throws {
        try answerTest("test1")
    }

    func testWithAnswer2LZ4Compress() throws {
        try answerTest("test2")
    }

    func testWithAnswer3LZ4Compress() throws {
        try answerTest("test3")
    }

    func testWithAnswer4LZ4Compress() throws {
        try answerTest("test4")
    }

    func testWithAnswer5LZ4Compress() throws {
        try answerTest("test5")
    }

    func testWithAnswer6LZ4Compress() throws {
        try answerTest("test6")
    }

    func testWithAnswer7LZ4Compress() throws {
        try answerTest("test7")
    }

    func testWithAnswer8LZ4Compress() throws {
        try answerTest("test8")
    }

    func testWithAnswer9LZ4Compress() throws {
        try answerTest("test9")
    }

}
