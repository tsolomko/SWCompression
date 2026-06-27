// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct SevenZipTests {

    private let testType: String = "7z"

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try SevenZipContainer.open(container: Data([0, 1, 2])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: (any Error).self) { try SevenZipContainer.open(container: testData) }
    }

    @Test func emptyInput() {
        #expect(throws: (any Error).self) { try SevenZipContainer.info(container: Data()) }
        #expect(throws: (any Error).self) { try SevenZipContainer.open(container: Data()) }
    }

    @Test func test1() throws {
        let testData = try Constants.data(forTest: "test1", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test1")

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test1.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xB4E89E84)

        #expect(entries[0].data == answerData)
    }

    @Test func test2() throws {
        let testData = try Constants.data(forTest: "test2", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 2)

        let answer1Data = try Constants.data(forAnswer: "test1")

        #expect(entries[0].info.name == "test1.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answer1Data.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xB4E89E84)

        #expect(entries[0].data == answer1Data)

        let answer4Data = try Constants.data(forAnswer: "test4")

        #expect(entries[1].info.name == "test4.answer")
        #expect(entries[1].info.type == .regular)
        #expect(entries[1].info.size == answer4Data.count)
        #expect(entries[1].info.permissions == Permissions(rawValue: 420))
        #expect(entries[1].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[1].info.modificationTime != nil)
        #expect(entries[1].info.accessTime == nil)
        #expect(entries[1].info.creationTime == nil)
        #expect(entries[1].info.hasStream)
        #expect(!entries[1].info.isEmpty)
        #expect(!entries[1].info.isAnti)
        #expect(entries[1].info.crc == 0xAEF524A3)

        #expect(entries[1].data == answer4Data)
    }

    @Test func test3() throws {
        let testData = try Constants.data(forTest: "test3", withType: testType)
        #expect(throws: Never.self) { try SevenZipContainer.info(container: testData) }
        #expect(throws: Never.self) { try SevenZipContainer.open(container: testData) }
    }

    @Test func antiFile() throws {
        let testData = try Constants.data(forTest: "test_anti_file", withType: testType)

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 6)

        for entry in entries {
            if entry.info.name == "test_create/test4.answer" {
                #expect(entry.info.isAnti)
            } else {
                #expect(!entry.info.isAnti)
            }
        }
    }

    @Test func multiBlocks() throws {
        // Container was created with "solid" options set to "off" (-ms=off).
        let testData = try Constants.data(forTest: "test_multi_blocks", withType: testType)

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        #expect(entries.count == 6)
    }

    @Test func allTimestamps() throws {
        // Container was created with "-mtc=on" and "-mta=on" options.
        let testData = try Constants.data(forTest: "test_all_timestamps", withType: testType)

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        #expect(entries.count == 6)

        for entry in entries {
            #expect(entry.info.creationTime != nil)
            #expect(entry.info.accessTime != nil)
            // Just in case...
            #expect(entry.info.modificationTime != nil)
        }
    }

    @Test func complicatedCodingScheme() throws {
        // Container was created with these options: "-mf=BCJ -m0=Copy -m1=Deflate -m2=Delta -m3=LZMA -m4=LZMA2"
        let testData = try Constants.data(forTest: "test_complicated_coding_scheme", withType: testType)
        // In this test case the most important thing is that information about entries must be read correctly.
        _ = try SevenZipContainer.info(container: testData)

        // It is expected for `open(container:) function to throw `SevenZipError.compressionNotSupported`, because of
        // the coders used.
        #expect(throws: SevenZipError.compressionNotSupported) { try SevenZipContainer.open(container: testData) }
    }

    @Test func encryptedHeader() throws {
        // Container was created with "-mhe=on".
        let testData = try Constants.data(forTest: "test_encrypted_header", withType: testType)

        #expect(throws: SevenZipError.encryptionNotSupported) { try SevenZipContainer.info(container: testData) }

        // There is no point in testing `open(container:)` function, because we are unable to get even files' info.
    }

    @Test func singleThread() throws {
        // Container was created with disabled multithreading options.
        // We check this just in case.
        let testData = try Constants.data(forTest: "test_single_thread", withType: testType)

        #expect(try SevenZipContainer.info(container: testData).count == 6)
        #expect(try SevenZipContainer.open(container: testData).count == 6)
    }

    @Test func bigContainer() throws {
        let testData = try Constants.data(forTest: "SWCompressionSourceCode", withType: testType)
        #expect(throws: Never.self) { try SevenZipContainer.info(container: testData) }
        #expect(throws: Never.self) { try SevenZipContainer.open(container: testData) }
    }

    @Test func bzip2() throws {
        // File in container compressed with BZip2.
        let testData = try Constants.data(forTest: "test_7z_bzip2", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xAEF524A3)

        #expect(entries[0].data == answerData)
    }

    @Test func deflate() throws {
        // File in container compressed with Deflate.
        let testData = try Constants.data(forTest: "test_7z_deflate", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xAEF524A3)

        #expect(entries[0].data == answerData)
    }

    @Test func lz4() throws {
        // File in container compressed with LZ4.
        let testData = try Constants.data(forTest: "test_7z_lz4", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xAEF524A3)

        #expect(entries[0].data == answerData)
    }

    @Test func copy() throws {
        // File in container is explicitly uncompressed.
        let testData = try Constants.data(forTest: "test_7z_copy", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xAEF524A3)

        #expect(entries[0].data == answerData)
    }

    @Test func unicode() throws {
        let testData = try Constants.data(forTest: "test_unicode", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "текстовый файл.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xA139BCEE)
        #expect(entries[0].data == Constants.текстовыйФайлData)
    }

    @Test func winContainer() throws {
        let testData = try Constants.data(forTest: "test_win", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 2)

        #expect(entries[0].info.name == "dir")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == nil)
        #expect(entries[0].info.permissions == Permissions(rawValue: 0))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x10))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(!entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == nil)

        #expect(entries[0].data == nil)

        #expect(entries[1].info.name == "text_win.txt")
        #expect(entries[1].info.type == .regular)
        #expect(entries[1].info.size == 15)
        #expect(entries[1].info.permissions == Permissions(rawValue: 0))
        #expect(entries[1].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[1].info.modificationTime != nil)
        #expect(entries[1].info.accessTime == nil)
        #expect(entries[1].info.creationTime == nil)
        #expect(entries[1].info.hasStream)
        #expect(!entries[1].info.isEmpty)
        #expect(!entries[1].info.isAnti)
        #expect(entries[1].info.crc == 0x1273FBD3)

        #expect(entries[1].data == "Hello, Windows!".data(using: .utf8))
    }

    @Test(.bug("https://github.com/tsolomko/SWCompression/pull/61", id: 61))
    func lzmaBigDict() throws {
        // Verifying the issue fixed by PR #61.
        // Previously, there was a crash, if LZMA dictionary size was encoded using all 4 bytes.
        let testData = try Constants.data(forTest: "test_lzma_big_dict", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)
        try #require(entries.count == 1)
        #expect(entries[0].info.name == "data")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == 16 * 1024 * 1024)
    }

    @Test func emptyFile() throws {
        let testData = try Constants.data(forTest: "test_empty_file", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_file")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(!entries[0].info.hasStream)
        #expect(entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == nil)

        #expect(entries[0].data == Data())
    }

    @Test func emptyDirectory() throws {
        let testData = try Constants.data(forTest: "test_empty_dir", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_dir")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == nil)
        #expect(entries[0].info.permissions == Permissions(rawValue: 493))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x10))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(!entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == nil)

        #expect(entries[0].data == nil)
    }

    @Test func emptyContainer() throws {
        let testData = try Constants.data(forTest: "test_empty_cont", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        #expect(entries.isEmpty)
    }

    @Test func deltaFilter() throws {
        let testData = try Constants.data(forTest: "test_delta_filter", withType: testType)
        let entries = try SevenZipContainer.open(container: testData)

        let answerData = try Constants.data(forAnswer: "test4")

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 0xAEF524A3)

        #expect(entries[0].data == answerData)
    }

    @Test func formatMinorVersions() throws {
        let answerData = try Constants.data(forAnswer: "test2")

        var testData = try Constants.data(forTest: "test_minor_version_2", withType: testType)
        var entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test2.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 0))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime == nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 4168830779)
        #expect(entries[0].data == answerData)

        testData = try Constants.data(forTest: "test_minor_version_3", withType: testType)
        entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test2.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime != nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 4168830779)
        #expect(entries[0].data == answerData)

        testData = try Constants.data(forTest: "test_minor_version_4", withType: testType)
        entries = try SevenZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test2.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == answerData.count)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime != nil)
        #expect(entries[0].info.hasStream)
        #expect(!entries[0].info.isEmpty)
        #expect(!entries[0].info.isAnti)
        #expect(entries[0].info.crc == 4168830779)
        #expect(entries[0].data == answerData)
    }

}
