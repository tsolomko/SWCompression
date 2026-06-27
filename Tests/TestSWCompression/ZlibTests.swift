// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct ZlibTests {

    private static let testType: String = "zlib"

    @Test func test() throws {
        let testName = "test"

        let testData = try Constants.data(forTest: testName, withType: ZlibTests.testType)
        let testZlibHeader = try ZlibHeader(archive: testData)

        #expect(testZlibHeader.compressionMethod == .deflate)
        #expect(testZlibHeader.compressionLevel == .defaultAlgorithm)
        #expect(testZlibHeader.windowSize == 32768)
    }

    @Test func full() throws {
        let testData = try Constants.data(forTest: "random_file", withType: ZlibTests.testType)
        let decompressedData = try ZlibArchive.unarchive(archive: testData)

        let answerData = try Constants.data(forAnswer: "test9")
        #expect(decompressedData == answerData)
    }

    @Test func create() throws {
        let testData = try Constants.data(forAnswer: "test9")
        let archiveData = ZlibArchive.archive(data: testData)
        let reextractedData = try ZlibArchive.unarchive(archive: archiveData)

        #expect(testData == reextractedData)
    }

    @Test func empty() throws {
        let testData = try Constants.data(forTest: "test_empty", withType: ZlibTests.testType)
        #expect((try ZlibArchive.unarchive(archive: testData)) == Data())
    }

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try ZlibArchive.unarchive(archive: Data([0x78])) }
        #expect(throws: (any Error).self) { try ZlibHeader(archive: Data([0x78])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: (any Error).self) { try ZlibArchive.unarchive(archive: testData) }
    }

    @Test func emptyInput() throws {
        #expect(throws: (any Error).self) { try ZlibArchive.unarchive(archive: Data()) }
    }

    @Test func checksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "random_file", withType: ZlibTests.testType)
        // Here we modify the stored value of adler32.
        testData[10249] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: ZlibError.self) { try ZlibArchive.unarchive(archive: testData) }
            if case let .some(.wrongAdler32(decompressedData)) = error {
                let answerData = try Constants.data(forAnswer: "test9")
                #expect(decompressedData == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try ZlibArchive.unarchive(archive: testData) } throws: { error in
                if case let .some(.wrongAdler32(decompressedData)) = error as? ZlibError {
                    let answerData = try Constants.data(forAnswer: "test9")
                    return decompressedData == answerData
                }
                return false
            }
        #endif
    }

    @Test func randomInputTruncations() throws {
        for testName in ["test", "random_file", "test_empty"] {
            let testData = try Constants.data(forTest: testName, withType: ZlibTests.testType)
            for _ in 0..<100 {
                let truncationIndex = Int.random(in: (testData.startIndex + 1)..<testData.endIndex)
                _ = try? ZlibArchive.unarchive(archive: testData[testData.startIndex..<truncationIndex])
            }
        }
    }

}
