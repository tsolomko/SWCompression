// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct DeflateCompressionTests {

    func answerTest(_ testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)
        let compressedData = Deflate.compress(data: answerData)
        let redecompressedData = try Deflate.decompress(data: compressedData)
        #expect(redecompressedData == answerData)
        if answerData.count > 0 { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print(String(format: "Deflate.\(testName).compressionRatio = %.3f", compressionRatio))
        }
    }

    func stringTest(_ string: String) throws {
        let answerData = Data(string.utf8)
        let compressedData = Deflate.compress(data: answerData)
        let redecompressedData = try Deflate.decompress(data: compressedData)
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

    @Test func answer1() throws {
        try self.answerTest("test1")
    }

    @Test func answer2() throws {
        try self.answerTest("test2")
    }

    @Test func answer3() throws {
        try self.answerTest("test3")
    }

    @Test func answer4() throws {
        try self.answerTest("test4")
    }

    @Test func answer5() throws {
        try self.answerTest("test5")
    }

    @Test func answer6() throws {
        try self.answerTest("test6")
    }

    @Test func answer7() throws {
        try self.answerTest("test7")
    }

    @Test func answer8() throws {
        try self.answerTest("test8")
    }

    @Test func answer9() throws {
        try self.answerTest("test9")
    }

    @Test func trickySequence() throws {
        // This test helped us find an issue with implementation (match index was wrongly used as cyclical index).
        // This test may become useless in the future if the encoder starts preferring creation of an uncompressed block
        // for this input due to changes to the compression logic.
        let answerData = Data([0x2E, 0x20, 0x2E, 0x20, 0x2E, 0x20, 0x20])
        let compressedData = Deflate.compress(data: answerData)
        let redecompressedData = try Deflate.decompress(data: compressedData)
        #expect(redecompressedData == answerData)
    }

}
