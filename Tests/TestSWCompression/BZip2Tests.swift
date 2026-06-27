// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct BZip2Tests {

    private let testType: String = "bz2"

    private func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: testType)
        let decompressedData = try BZip2.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: testName)
        #expect(decompressedData == answerData)
    }

    @Test func test1() throws {
        try perform(test: "test1")
    }

    @Test func test2() throws {
        try perform(test: "test2")
    }

    @Test func test3() throws {
        try perform(test: "test3")
    }

    @Test func test4() throws {
        try perform(test: "test4")
    }

    @Test func test5() throws {
        try perform(test: "test5")
    }

    @Test func test6() throws {
        try perform(test: "test6")
    }

    @Test func test7() throws {
        try perform(test: "test7")
    }

    @Test func test8() throws {
        try perform(test: "test8")
    }

    @Test func test9() throws {
        try perform(test: "test9")
    }

    @Test(.bug("https://github.com/tsolomko/SWCompression/issues/21", id: 21))
    func nonStandardRunLength() throws {
        try perform(test: "test_nonstandard_runlength")
    }

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try BZip2.decompress(data: Data([0])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: (any Error).self) { try BZip2.decompress(data: testData) }
    }

    @Test func truncatedInput() throws {
        // This tests that encountering data truncated in the middle of a Huffman symbol correctly throws an error
        // (and doesn't crash).
        let testData = try Constants.data(forTest: "test1", withType: testType)[0...40]
        #expect(throws: (any Error).self) { try BZip2.decompress(data: testData) }
    }

    @Test func emptyInput() {
        #expect(throws: (any Error).self) { try BZip2.decompress(data: Data()) }
    }

    @Test func checksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test1", withType: testType)
        // The checksum is the last 4 bytes.
        testData[testData.endIndex - 2] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: BZip2Error.self) { try BZip2.decompress(data: testData) }
            if case let .some(.wrongCRC(decompressedData)) = error {
                let answerData = try Constants.data(forAnswer: "test1")
                #expect(decompressedData == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try BZip2.decompress(data: testData) } throws: { error in
                if case let .some(.wrongCRC(decompressedData)) = error as? BZip2Error {
                    let answerData = try Constants.data(forAnswer: "test1")
                    return decompressedData == answerData
                }
                return false
            }
        #endif
    }

    @Test func randomInputTruncations() throws {
        // Verify that there is no crash when input is randomly truncated. It can throw error or produce an output
        // depending on luck (in an extremely rare case the truncated input could somehow still be valid). Thus, there
        // is no #expect in this test.
        for i in 1...9 {
            let testName = "test\(i)"
            let testData = try Constants.data(forTest: testName, withType: testType)
            // It would be better to increase amount of different truncations tested, but we hit runtime limits in CI.
            for _ in 0..<5 {
                let truncationIndex = Int.random(in: (testData.startIndex + 1)..<testData.endIndex)
                _ = try? BZip2.decompress(data: testData[testData.startIndex..<truncationIndex])
            }
        }
    }

    @Test func multiDecompress() throws {
        var input = Data()
        for i in 1...5 {
            let testName = "test\(i)"
            let testData = try Constants.data(forTest: testName, withType: testType)
            input.append(testData)
        }
        let output = try BZip2.multiDecompress(data: input)
        for i in 1...5 {
            let testName = "test\(i)"
            let answerData = try Constants.data(forAnswer: testName)
            #expect(output[i - 1] == answerData)
        }
    }

    @Test func multiDecompressSingleArchive() throws {
        for i in 1...5 {
            let testName = "test\(i)"
            let testData = try Constants.data(forTest: testName, withType: testType)
            let answerData = try Constants.data(forAnswer: testName)
            let output = try BZip2.multiDecompress(data: testData)
            #expect(output.first! == answerData)
        }
    }

    @Test func multiDecompressRandomTruncations() throws {
        // Verify that there is no crash when input is randomly truncated. It can throw error or produce an output
        // depending on luck (in an extremely rare case the truncated input could somehow still be valid). Thus, there
        // is no #expect in this test.
        var input = Data()
        for i in 1...5 {
            let testName = "test\(i)"
            let testData = try Constants.data(forTest: testName, withType: testType)
            input.append(testData)
        }
        for _ in 0..<5 {
            let truncationIndex = Int.random(in: (input.startIndex + 1)..<input.endIndex)
            _ = try? BZip2.multiDecompress(data: input[input.startIndex..<truncationIndex])
        }
    }

}
