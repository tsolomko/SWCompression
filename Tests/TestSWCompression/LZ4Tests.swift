// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct LZ4Tests {

    private let testType: String = "lz4"

    // These tests test frames with independent blocks (since they all have only one block). The frames also have
    // additional features enabled, such as content size and block checksums. They also test legacy frame format.

    private func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: testName)
        #expect(decompressedData == answerData)
    }

    private func perform(legacyTest testName: String) throws {
        let testData = try Constants.data(forTest: testName + "_legacy", withType: testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: testName)
        #expect(decompressedData == answerData)
    }

    @Test func test1() throws {
        try perform(test: "test1")
        try perform(legacyTest: "test1")
    }

    @Test func test2() throws {
        try perform(test: "test2")
        try perform(legacyTest: "test2")
    }

    @Test func test3() throws {
        try perform(test: "test3")
        try perform(legacyTest: "test3")
    }

    @Test func test4() throws {
        try perform(test: "test4")
        try perform(legacyTest: "test4")
    }

    @Test func test5() throws {
        try perform(test: "test5")
        try perform(legacyTest: "test5")
    }

    @Test func test6() throws {
        try perform(test: "test6")
        try perform(legacyTest: "test6")
    }

    @Test func test7() throws {
        try perform(test: "test7")
        try perform(legacyTest: "test7")
    }

    @Test func test8() throws {
        try perform(test: "test8")
        try perform(legacyTest: "test8")
    }

    @Test func test9() throws {
        try perform(test: "test9")
        try perform(legacyTest: "test9")
    }

    @Test func dependentBlocks() throws {
        // This test contains dependent blocks (with the size of 64 kB), as well as has additional features enabled,
        // such as content size and block checksums.
        let testData = try Constants.data(forTest: "SWCompressionSourceCode.tar", withType: testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        #expect(decompressedData == answerData)
    }
    
    @Test func emptyInput() {
        #expect(throws: DataError.truncated) { try LZ4.decompress(data: Data()) }
    }

    @Test func shortInput() {
        #expect(throws: DataError.truncated) { try LZ4.decompress(data: Data([0])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: DataError.corrupted) { try LZ4.decompress(data: testData) }
    }

    @Test func skippableFrame() throws {
        let testData = try Constants.data(forTest: "test_skippable_frame", withType: testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: "test4")
        #expect(decompressedData == answerData)
    }

    @Test func legacyFrameMultipleBlocks() throws {
        let testData = try Constants.data(forTest: "zeros", withType: testType)
        let decompressedData = try LZ4.decompress(data: testData)

        let answerData = Data(count: 18874368)
        #expect(decompressedData == answerData)
    }

    @Test func blockSizes() throws {
        // These tests don't include any checksums (becaused they are too time consuming). Only content sizes are used
        // for verification. We still test both dependent and independent blocks.
        let answerData = Data(count: 5242880)

        for blockSize in ["4", "5", "6", "7", "1234"] {
            for dep in ["", "_BD"] {
                let testData = try Constants.data(forTest: "test_B" + blockSize + dep, withType: testType)
                let decompressedData = try LZ4.decompress(data: testData)
                #expect(decompressedData == answerData)
            }
        }
    }

    @Test func dictionary() throws {
        // Unfortunately, LZ4 reference implementation doesn't save dictID inside a frame, even though it is present
        // in the dictionary file. So we test dictID comparison by using the manually constructed file (the last test).
        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        let dictData = try Constants.data(forTest: "lz4_dict", withType: "")

        var testData = try Constants.data(forTest: "test_dict_B5", withType: testType)
        var decompressedData = try LZ4.decompress(data: testData, dictionary: dictData)
        #expect(decompressedData == answerData)

        testData = try Constants.data(forTest: "test_dict_B5_BD", withType: testType)
        decompressedData = try LZ4.decompress(data: testData, dictionary: dictData)
        #expect(decompressedData == answerData)

        testData = try Constants.data(forTest: "test_dict_B5_dictID", withType: testType)
        decompressedData = try LZ4.decompress(data: testData, dictionary: dictData, dictionaryID: 20000)
        #expect(decompressedData == answerData)
    }

    @Test func smallDictionary() throws {
        // Here we test decompression with a small dictionary, i.e. smaller than standard "lookback window" of 64 KB.
        let answerData = try Constants.data(forTest: "SWCompressionSourceCode", withType: "tar")
        let dictData = try Constants.data(forTest: "lz4_small_dict", withType: "")

        var testData = try Constants.data(forTest: "test_small_dict_B5", withType: testType)
        var decompressedData = try LZ4.decompress(data: testData, dictionary: dictData)
        #expect(decompressedData == answerData)

        testData = try Constants.data(forTest: "test_small_dict_B5_BD", withType: testType)
        decompressedData = try LZ4.decompress(data: testData, dictionary: dictData)
        #expect(decompressedData == answerData)
    }

    @Test func multiFrameDecompress() throws {
        // The test file contains three frames:
        // - Legacy frame format, compressed test1.answer,
        // - Skippable frame with 1233 bytes of random data,
        // - Normal frame with compressed test4.answer.
        let testData = try Constants.data(forTest: "test_multi_frame", withType: testType)
        let result = try LZ4.multiDecompress(data: testData)

        try #require(result.count == 2)
        var answerData = try Constants.data(forAnswer: "test1")
        #expect(result[0] == answerData)
        answerData = try Constants.data(forAnswer: "test4")
        #expect(result[1] == answerData)
    }

    @Test func checksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test1", withType: testType)
        // The content checksum is the last 4 bytes.
        testData[testData.endIndex - 2] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: DataError.self) { try LZ4.decompress(data: testData) }
            if case let .some(.checksumMismatch(decompressedData)) = error {
                try #require(decompressedData.count == 1)
                let answerData = try Constants.data(forAnswer: "test1")
                #expect(decompressedData.first == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try LZ4.decompress(data: testData) } throws: { error in
                if case let .some(.checksumMismatch(decompressedData)) = error as? DataError {
                    let answerData = try Constants.data(forAnswer: "test1")
                    return decompressedData.count == 1 && decompressedData.first == answerData
                }
                return false
            }
        #endif
    }

    @Test func randomInputTruncations() throws {
        for i in 1...9 {
            let testName = "test\(i)"
            let testData = try Constants.data(forTest: testName, withType: testType)
            for _ in 0..<100 {
                let truncationIndex = Int.random(in: (testData.startIndex + 1)..<testData.endIndex)
                _ = try? LZ4.decompress(data: testData[testData.startIndex..<truncationIndex])
            }
        }
    }

}
