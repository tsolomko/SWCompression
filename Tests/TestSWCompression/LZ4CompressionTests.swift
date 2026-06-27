// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct LZ4CompressionTests {

    private func answerTest(_ testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)
        let compressedData = LZ4.compress(data: answerData)
        let redecompressedData = try LZ4.decompress(data: compressedData)
        #expect(redecompressedData == answerData)
        if answerData.count > 0 { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print(String(format: "LZ4.\(testName).compressionRatio = %.3f", compressionRatio))
        }
    }

    private func stringTest(_ string: String) throws {
        let answerData = Data(string.utf8)
        let compressedData = LZ4.compress(data: answerData)
        let redecompressedData = try LZ4.decompress(data: compressedData)
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

    @Test func answer7() throws {
        try answerTest("test7")
    }

    @Test func answer8() throws {
        try answerTest("test8")
    }

    @Test func answer9() throws {
        try answerTest("test9")
    }

    @Test func randomOptions() throws {
        for i in 1...9 {
            let independentBlocks = Bool.random()
            let blockChecksums = Bool.random()
            let contentChecksum = Bool.random()
            let contentSize = Bool.random()
            let blockSize = Int.random(in: 1024...4 * 1024 * 1024)

            let answerData = try Constants.data(forAnswer: "test\(i)")
            let compressedData = LZ4.compress(data: answerData, independentBlocks: independentBlocks,
                                              blockChecksums: blockChecksums, contentChecksum: contentChecksum,
                                              contentSize: contentSize, blockSize: blockSize)
            do {
                let redecompressedData = try LZ4.decompress(data: compressedData)
                // There are some weird type-checking issues with converting concatenated strings into Comment type, so
                // we have to do it explicitly.
                #expect(redecompressedData == answerData, Comment(rawValue: "Test #\(i) failed (result mismatch) with the following " +
                                               "options: independent blocks = \(independentBlocks), block checksums = \(blockChecksums), " +
                                               "content checksum = \(contentChecksum), content size = \(contentSize), " +
                                               "block size = \(blockSize) bytes"))
            } catch let error {
                Issue.record(Comment(rawValue: "Test #\(i) failed (DataError.\(error) caught) with the following options: " +
                                        "independent blocks = \(independentBlocks), block checksums = \(blockChecksums), " +
                                        "content checksum = \(contentChecksum), content size = \(contentSize), " +
                                        "block size = \(blockSize) bytes"))
            }
        }
    }

    @Test func dictionary() throws {
        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        let dictData = try Constants.data(forTest: "lz4_dict", withType: "")

        var compressedData = LZ4.compress(data: answerData, independentBlocks: true, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        var redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        #expect(redecompressedData == answerData)
        var compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print(String(format: "LZ4.dict.compressionRatio = %.3f", compressionRatio))

        compressedData = LZ4.compress(data: answerData, independentBlocks: false, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        #expect(redecompressedData == answerData)
        compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print(String(format: "LZ4.dict_BD.compressionRatio = %.3f", compressionRatio))

        compressedData = LZ4.compress(data: answerData, independentBlocks: true, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: 20000)
        redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData, dictionaryID: 20000)
        #expect(redecompressedData == answerData)
        // If the wrong dictionary ID is specified the decompression should fail.
        #expect(throws: (any Error).self) { try LZ4.decompress(data: compressedData, dictionary: dictData, dictionaryID: 12345) }
    }

    @Test func smallDictionary() throws {
        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        let dictData = try Constants.data(forTest: "lz4_small_dict", withType: "")

        var compressedData = LZ4.compress(data: answerData, independentBlocks: true, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        var redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        #expect(redecompressedData == answerData)
        var compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print(String(format: "LZ4.small_dict.compressionRatio = %.3f", compressionRatio))

        compressedData = LZ4.compress(data: answerData, independentBlocks: false, blockChecksums: Bool.random(),
                                              contentChecksum: Bool.random(), contentSize: Bool.random(),
                                              blockSize: 256 * 1024, dictionary: dictData, dictionaryID: nil)
        redecompressedData = try LZ4.decompress(data: compressedData, dictionary: dictData)
        #expect(redecompressedData == answerData)
        compressionRatio = Double(answerData.count) / Double(compressedData.count)
        print(String(format: "LZ4.small_dict_BD.compressionRatio = %.3f", compressionRatio))
    }

    @Test func trickySequence() throws {
        // This test helped us find an issue with implementation (match index was wrongly used as cyclical index).
        // The last 10 bytes (0x01 - 0x00) are only here to allow creation of a sequence with a match.
        let answerData = Data([0x61, 0x6C, 0x20, 0x2D, 0x43, 0x20, 0x2D, 0x43, 0x20, 0x2D, 0x2D, 0x01, 0x02, 0x03, 0x04,
                              0x05, 0x06, 0x07, 0x08, 0x09, 0x00])
        let compressedData = LZ4.compress(data: answerData, independentBlocks: false, blockChecksums: true,
                                              contentChecksum: true, contentSize: true)
        let redecompressedData = try LZ4.decompress(data: compressedData)
        #expect(redecompressedData == answerData)
    }

}
