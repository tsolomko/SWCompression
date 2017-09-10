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

    func test1BZip2Compress() throws {
        try stringTest("Hello, World!\n")
    }

    func test2BZip2Compress() throws {
        try stringTest("AAAAAAABBBBCCCD")
    }

    func test3BZip2Compress() throws {
        try stringTest("AAAAAAA")
    }

    func test4BZip2Compress() throws {
        try stringTest("qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890")
    }

}
