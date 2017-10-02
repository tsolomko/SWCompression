// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class BZip2CompressTests: XCTestCase {

    static let testType: String = "bz2"

    func answerTest(_ answerName: String) throws {
        guard let answerURL = Constants.url(forAnswer: answerName) else {
            XCTFail("Unable to get asnwer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        let compressedData = BZip2.compress(data: answerData)
        let redecompressedData = try BZip2.decompress(data: compressedData)

        XCTAssertEqual(redecompressedData, answerData)

        #if PERF_TESTS
            print("Performing performance tests for cbzip2.\(testName)")
            self.measure {
                _ = try? BZip2.compress(data: answerData)
            }
        #endif
    }

    func stringTest(_ string: String) throws {
        guard let stringData = string.data(using: .utf8) else {
            XCTFail("Unable to convert String to Data.")
            return
        }

        let compressedData = BZip2.compress(data: stringData)
        let redecompressedData = try BZip2.decompress(data: compressedData)

        XCTAssertEqual(redecompressedData, stringData)
    }

    func testBZip2CompressStrings() throws {
        try stringTest("banana")
        try stringTest("abaaba")
        try stringTest("abracadabra")
        try stringTest("cabbage")
        try stringTest("baabaabac")
        try stringTest("AAAAAAABBBBCCCD")
        try stringTest("AAAAAAA")
        try stringTest("qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890")
    }

    func testBZip2CompressBytes() throws {
        var bytes = ""
        for i: UInt8 in 0...255 {
            bytes += String(format: "%c", i)
        }
        try stringTest(bytes)
    }

    func testWithAnswer1BZip2Compress() throws {
        try answerTest("test1")
    }

    func testWithAnswer2BZip2Compress() throws {
        try answerTest("test2")
    }

    func testWithAnswer3BZip2Compress() throws {
        try answerTest("test3")
    }

    func testWithAnswer4BZip2Compress() throws {
        try answerTest("test4")
    }

    func testWithAnswer5BZip2Compress() throws {
        try answerTest("test5")
    }

    func testWithAnswer6BZip2Compress() throws {
        try answerTest("test6")
    }

    #if LONG_TESTS

    func testWithAnswer7BZip2Compress() throws {
        try answerTest("test7")
    }

    #endif

    func testWithAnswer8BZip2Compress() throws {
        try answerTest("test8")
    }

    func testWithAnswer9BZip2Compress() throws {
        try answerTest("test9")
    }

}
