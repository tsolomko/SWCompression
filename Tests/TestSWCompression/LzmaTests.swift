// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct LzmaTests {

    private static let testType: String = "lzma"

    func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: LzmaTests.testType)
        let decompressedData = try LZMA.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: "test8")
        #expect(decompressedData == answerData)
    }

    @Test func lzma8() throws {
        try self.perform(test: "test8")
    }

    @Test func lzma9() throws {
        try self.perform(test: "test9")
    }

    @Test func lzma10() throws {
        try self.perform(test: "test10")
    }

    @Test func lzma11() throws {
        try self.perform(test: "test11")
    }

    @Test func lzmaEmpty() throws {
        let testData = try Constants.data(forTest: "test_empty", withType: LzmaTests.testType)
        #expect(try LZMA.decompress(data: testData) == Data())
    }

    @Test func truncatedInput() {
        // Not enough data for LZMA properties.
        #expect(throws: (any Error).self) { try LZMA.decompress(data: Data([0, 1, 2, 3])) }
        // Not enough data to initialize range decoder.
        #expect(throws: (any Error).self) { try LZMA.decompress(data: Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test7")
        #expect(throws: (any Error).self) { try LZMA.decompress(data: testData) }
    }

    @Test func emptyInput() {
        #expect(throws: (any Error).self) { try LZMA.decompress(data: Data()) }
        #expect(throws: (any Error).self) { try LZMA2.decompress(data: Data()) }
    }

}
