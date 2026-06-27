// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct XZTests {

    private let testType: String = "xz"

    private func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: testType)
        let decompressedData = try XZArchive.unarchive(archive: testData)

        let answerData = try Constants.data(forAnswer: testName)
        #expect(decompressedData == answerData)
    }

    @Test func xz1() throws {
        try perform(test: "test1")
    }

    @Test func xz2() throws {
        try perform(test: "test2")
    }

    @Test func xz3() throws {
        try perform(test: "test3")
    }

    @Test func xz4() throws {
        // This test contains padding!
        try perform(test: "test4")
    }

    @Test func xz5() throws {
        try perform(test: "test5")
    }

    @Test func xz6() throws {
        try perform(test: "test6")
    }

    @Test func xz7() throws {
        try perform(test: "test7")
    }

    @Test func xz8() throws {
        try perform(test: "test8")
    }

    @Test func xz9() throws {
        try perform(test: "test9")
    }

    @Test func multiStreamNoPadding() throws {
        // Doesn't contain any padding.
        let testData = try Constants.data(forTest: "test_multi", withType: testType)
        let splitDecompressedData = try XZArchive.splitUnarchive(archive: testData)
        try #require(splitDecompressedData.count == 4)

        var answerData = Data()
        for i in 1...4 {
            let currentAnswerData = try Constants.data(forAnswer: "test\(i)")
            answerData.append(currentAnswerData)
            #expect(splitDecompressedData[i - 1] == currentAnswerData)
        }

        let decompressedData = try XZArchive.unarchive(archive: testData)
        #expect(decompressedData == answerData)
    }

    @Test func multiStreamComplexPadding() throws {
        // After first stream - no padding.
        // After second - 4 bytes of padding.
        // Third - 8 bytes.
        // At the end - 4 bytes.
        let testData = try Constants.data(forTest: "test_multi_pad", withType: testType)
        let splitDecompressedData = try XZArchive.splitUnarchive(archive: testData)
        try #require(splitDecompressedData.count == 4)

        var answerData = Data()
        for i in 1...4 {
            let currentAnswerData = try Constants.data(forAnswer: "test\(i)")

            answerData.append(currentAnswerData)
            #expect(splitDecompressedData[i - 1] == currentAnswerData)
        }

        let decompressedData = try XZArchive.unarchive(archive: testData)
        #expect(decompressedData == answerData)
    }

    @Test func deltaFilter() throws {
        let testData = try Constants.data(forTest: "test_delta_filter", withType: testType)
        let decompressedData = try XZArchive.unarchive(archive: testData)

        let answerData = try Constants.data(forAnswer: "test4")
        #expect(decompressedData == answerData)
    }

    @Test func sha256Check() throws {
        let testData = try Constants.data(forTest: "test_sha256", withType: testType)
        let decompressedData = try XZArchive.unarchive(archive: testData)

        let answerData = try Constants.data(forAnswer: "test4")
        #expect(decompressedData == answerData)
    }

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try XZArchive.unarchive(archive: Data([0, 1, 2])) }
        #expect(throws: (any Error).self) { try XZArchive.splitUnarchive(archive: Data([0, 1, 2])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: (any Error).self) { try XZArchive.unarchive(archive: testData) }
    }

    @Test func checksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test1", withType: testType)
        // Here we modify the stored value of crc64.
        testData[46] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: XZError.self) { try XZArchive.unarchive(archive: testData) }
            if case let .some(.wrongCheck(decompressedData)) = error {
                try #require(decompressedData.count == 1)
                let answerData = try Constants.data(forAnswer: "test1")
                #expect(decompressedData.first == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try XZArchive.unarchive(archive: testData) } throws: { error in
                if case let .some(.wrongCheck(decompressedData)) = error as? XZError {
                    let answerData = try Constants.data(forAnswer: "test1")
                    return decompressedData.count == 1 && decompressedData.first == answerData
                }
                return false
            }
        #endif
    }

    @Test func multiStreamChecksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test_multi", withType: testType)
        // Here we modify the stored value of crc64.
        testData[2346] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: XZError.self) { try XZArchive.splitUnarchive(archive: testData) }
            if case let .some(.wrongCheck(decompressedData)) = error {
                try #require(decompressedData.count == 2)
                var answerData = [try Constants.data(forAnswer: "test1")]
                answerData.append(try Constants.data(forAnswer: "test2"))
                #expect(decompressedData == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try XZArchive.splitUnarchive(archive: testData) } throws: { error in
                if case let .some(.wrongCheck(decompressedData)) = error as? XZError {
                    var answerData = [try Constants.data(forAnswer: "test1")]
                    answerData.append(try Constants.data(forAnswer: "test2"))
                    return decompressedData.count == 2 && decompressedData == answerData
                }
                return false
            }
        #endif
    }

}
