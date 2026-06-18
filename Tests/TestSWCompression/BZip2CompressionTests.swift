// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct BZip2CompressionTests {

    func answerTest(_ testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)
        let compressedData = BZip2.compress(data: answerData)
        let redecompressedData = try BZip2.decompress(data: compressedData)
        #expect(redecompressedData == answerData)
        if answerData.count > 0 { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print(String(format: "BZip2.\(testName).compressionRatio = %.3f", compressionRatio))
        }
    }

    func stringTest(_ string: String) throws {
        let answerData = Data(string.utf8)

        let compressedData = BZip2.compress(data: answerData)

        let redecompressedData = try BZip2.decompress(data: compressedData)
        #expect(redecompressedData == answerData)
    }

    @Test func compressStrings() throws {
        try stringTest("ban")
        try stringTest("banana")
        try stringTest("abaaba")
        try stringTest("abracadabra")
        try stringTest("cabbage")
        try stringTest("baabaabac")
        try stringTest("AAAAAAABBBBCCCD")
        try stringTest("AAAAAAA")
        try stringTest("qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890")
    }

    @Test func compressBytes() throws {
        var bytes = ""
        for i: UInt8 in 0...255 {
            bytes += String(format: "%c", i)
        }
        try stringTest(bytes)
    }

    @Test func answer1() throws {
        try answerTest("test1")
    }

    @Test func answer2() throws {
        try answerTest("test2")
    }

    @Test func answer3() throws {
        try answerTest("test3")
    }

    @Test func answer4() throws {
        try answerTest("test4")
    }

    @Test func answer5() throws {
        try answerTest("test5")
    }

    @Test func answer6() throws {
        try answerTest("test6")
    }

//    @Test func answer7() throws {
//        try answerTest("test7")
//    }

    @Test func answer8() throws {
        try answerTest("test8")
    }

    @Test func answer9() throws {
        try answerTest("test9")
    }

    @Test(.bug("https://github.com/tsolomko/SWCompression/issues/38", id: 38))
    func bwRoundtrip() throws {
        // This test is inspired by the reported issue #38 that uncovered a mistake with a pointer variable in BWT.
        // "1"s can be anything (except zero), but it must be the same byte value in all places.
        // Two consecutive zeros in the middle seem to be crucial for some reason.
        let testData = Data([0, 1, 0, 1, 0, 0, 1, 0, 1])
        let compressedData = BZip2.compress(data: testData)
        let redecompressedData = try BZip2.decompress(data: compressedData)
        #expect(redecompressedData == testData)
    }

}
