// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct ZipTests {

    private static let testType: String = "zip"

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try ZipContainer.open(container: Data([0, 1, 2, 3, 4, 5, 6, 7])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: (any Error).self) { try ZipContainer.open(container: testData) }
    }

    @Test func emptyInput() {
        #expect(throws: (any Error).self) { try ZipContainer.info(container: Data()) }
        #expect(throws: (any Error).self) { try ZipContainer.open(container: Data()) }
    }

    @Test func bigContainer() throws {
        let testData = try Constants.data(forTest: "SWCompressionSourceCode", withType: ZipTests.testType)
        #expect(throws: Never.self) { try ZipContainer.open(container: testData) }
    }

    @Test func customExtraField() throws {
        let testData = try Constants.data(forTest: "test_custom_extra_field", withType: ZipTests.testType)

        // First, we check that without enabling support for our custom extra field, ZipContainer doesn't recognize it.
        var entries = try ZipContainer.open(container: testData)
        try #require(entries.count == 1)
        #expect(entries[0].info.customExtraFields.count == 0)

        // Enable support for custom extra field.
        ZipContainer.customExtraFields[0x0646] = TestZipExtraField.self

        entries = try ZipContainer.open(container: testData)
        try #require(entries.count == 1)

        let entry = entries[0]
        #expect(entry.info.customExtraFields.count == 2)

        for customExtraField in entry.info.customExtraFields {
            #expect(customExtraField is TestZipExtraField)
            #expect(customExtraField.id == TestZipExtraField.id)
            if customExtraField.size == 13 {
                #expect(customExtraField.location == .centralDirectory)
                #expect((customExtraField as? TestZipExtraField)?.helloString == "Hello, Extra!")
            } else if customExtraField.size == 20 {
                #expect(customExtraField.location == .localHeader)
                #expect((customExtraField as? TestZipExtraField)?.helloString == "Hello, Local Header!")
            } else {
                Issue.record("Wrong size for custom extra field.")
            }
        }

        // Disable support for the custom extra field, so it doesn't interfere with other tests.
        ZipContainer.customExtraFields.removeValue(forKey: 0x0646)
    }

    @Test func zip64() throws {
        let testData = try Constants.data(forTest: "test_zip64", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 6)

        for entry in entries {
            #expect(entry.info.fileSystemType == .unix)
            #expect(entry.info.ownerID == nil)
            #expect(entry.info.groupID == nil)
            #expect(entry.info.comment == "")
            // Checking times' values is a bit difficult since they are extremely precise.
            #expect(entry.info.modificationTime != nil)
            #expect(entry.info.accessTime == nil)
            #expect(entry.info.creationTime == nil)
        }
    }

    @Test func dataDescriptor() throws {
        let testData = try Constants.data(forTest: "test_data_descriptor", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 6)

        for entry in entries {
            #expect(entry.info.fileSystemType == .unix)
            #expect(entry.info.ownerID == 501)
            #expect(entry.info.groupID == 20)
            #expect(entry.info.comment == "")
            // Checking times' values is a bit difficult since they are extremely precise.
            #expect(entry.info.modificationTime != nil)
            #expect(entry.info.accessTime != nil)
            #expect(entry.info.creationTime == nil)
            if entry.info.name == "test_dir/dir_with_file/test_file" {
                #expect(entry.info.size == 14)
                #expect(entry.info.crc == 0xB4E89E84)
            } else if entry.info.name == "test_dir/random_file" {
                #expect(entry.info.size == 10250)
                #expect(entry.info.crc == 0xD888DA2E)
            }
        }
    }

    @Test func unicode() throws {
        let testData = try Constants.data(forTest: "test_unicode", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "текстовый файл")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.fileSystemType == .unix)
        #expect(entries[0].info.compressionMethod == .deflate)
        #expect(entries[0].info.isTextFile)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime == nil)
        #expect(entries[0].data == Constants.текстовыйФайлData)
    }

    @Test func zipLZMA() throws {
        let testData = try Constants.data(forTest: "test_zip_lzma", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.fileSystemType == .unix)
        #expect(!entries[0].info.isTextFile)
        #expect(entries[0].info.compressionMethod == .lzma)
        #expect(entries[0].info.ownerID == nil)
        #expect(entries[0].info.groupID == nil)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime != nil)

        let answerData = try Constants.data(forAnswer: "test4")
        #expect(entries[0].data == answerData)
    }

    @Test func zipBZip2() throws {
        let testData = try Constants.data(forTest: "test_zip_bzip2", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test4.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.fileSystemType == .unix)
        #expect(!entries[0].info.isTextFile)
        #expect(entries[0].info.compressionMethod == .bzip2)
        #expect(entries[0].info.ownerID == nil)
        #expect(entries[0].info.groupID == nil)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x20))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime != nil)

        let answerData = try Constants.data(forAnswer: "test4")
        #expect(entries[0].data == answerData)
    }

    @Test func winContainer() throws {
        let testData = try Constants.data(forTest: "test_win", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 2)

        #expect(entries[0].info.name == "dir/")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.fileSystemType == .fat)
        #expect(entries[0].info.compressionMethod == .copy)
        #expect(!entries[0].info.isTextFile)
        #expect(entries[0].info.ownerID == nil)
        #expect(entries[0].info.groupID == nil)
        #expect(entries[0].info.permissions == Permissions(rawValue: 0))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x10))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime != nil)

        #expect(entries[0].data == nil)

        #expect(entries[1].info.name == "text_win.txt")
        #expect(entries[1].info.type == .regular)
        #expect(entries[1].info.size == 15)
        #expect(entries[1].info.dosAttributes?.contains(.directory) == false)
        #expect(entries[1].info.fileSystemType == .fat)
        #expect(!entries[1].info.isTextFile)
        #expect(entries[1].info.ownerID == nil)
        #expect(entries[1].info.groupID == nil)
        #expect(entries[1].info.permissions == Permissions(rawValue: 0))
        #expect(entries[1].info.dosAttributes == DosAttributes(rawValue: 0x20))
        #expect(entries[1].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[1].info.modificationTime != nil)
        #expect(entries[1].info.accessTime != nil)
        #expect(entries[1].info.creationTime != nil)

        #expect(entries[1].data == "Hello, Windows!".data(using: .utf8))
    }

    @Test func emptyFile() throws {
        let testData = try Constants.data(forTest: "test_empty_file", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_file")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.fileSystemType == .unix)
        #expect(entries[0].info.compressionMethod == .copy)
        #expect(!entries[0].info.isTextFile)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime == nil)

        #expect(entries[0].data == Data())
    }

    @Test func emptyDirectory() throws {
        let testData = try Constants.data(forTest: "test_empty_dir", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_dir/")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.fileSystemType == .unix)
        #expect(entries[0].info.compressionMethod == .copy)
        #expect(!entries[0].info.isTextFile)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.permissions == Permissions(rawValue: 493))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0x10))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime == nil)

        #expect(entries[0].data == nil)
    }

    @Test func emptyContainer() throws {
        let testData = try Constants.data(forTest: "test_empty_cont", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        #expect(entries.isEmpty)
    }

    @Test func badCdExtTs() throws {
        // Tests ability to not crash when opening ZIP files with non well-formed Extended Timestamp extra field.
        // Such fields are sometimes present in Central Directory of ZIP files created by Finder in some versions of macOS.
        let testData = try Constants.data(forTest: "bad_cd_ext_ts", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)
        try #require(entries.count == 2)
        let answerData = try Constants.data(forAnswer: "test4")
        #expect(entries[1].data == answerData)
    }

    @Test(.bug("https://github.com/tsolomko/SWCompression/issues/66", id: 66))
    func dosLatinUS() throws {
        // This test checks that CP437 encoding is correctly used when there is no indication the file name is in UTF-8.
        // We introduced several CP437-specific characters from the 0x80-0xFF range into "test1.answer" to test this.
        // Note, that we didn't used normal characters from the 0x00-0x7F range that don't match the characters from
        // UTF-8 with the same codes, since they are interpreted as control characters by Foundation.
        let testData = try Constants.data(forTest: "test_dos_latin_us", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "teüë1.½n█wΩ±")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.fileSystemType == .unix)
        #expect(!entries[0].info.isTextFile)
        #expect(entries[0].info.compressionMethod == .copy)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0))
        #expect(entries[0].info.comment == "")
        // Checking times' values is a bit difficult since they are extremely precise.
        #expect(entries[0].info.modificationTime != nil)
        #expect(entries[0].info.accessTime != nil)
        #expect(entries[0].info.creationTime == nil)

        let answerData = try Constants.data(forAnswer: "test1")
        #expect(entries[0].data == answerData)
    }

    @Test func checksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test_unicode", withType: ZipTests.testType)
        // Here we modify the stored value of crc32.
        testData[16] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: ZipError.self) { try ZipContainer.open(container: testData) }
            if case let .some(.wrongCRC(entries)) = error {
                try #require(entries.count == 1)
                #expect(entries[0].info.name == "текстовый файл")
                #expect(entries[0].info.type == .regular)
                #expect(entries[0].info.fileSystemType == .unix)
                #expect(entries[0].info.compressionMethod == .deflate)
                #expect(entries[0].info.isTextFile)
                #expect(entries[0].info.ownerID == 501)
                #expect(entries[0].info.groupID == 20)
                #expect(entries[0].info.permissions == Permissions(rawValue: 420))
                #expect(entries[0].info.dosAttributes == DosAttributes(rawValue: 0))
                #expect(entries[0].info.comment == "")
                // Checking times' values is a bit difficult since they are extremely precise.
                #expect(entries[0].info.modificationTime != nil)
                #expect(entries[0].info.accessTime != nil)
                #expect(entries[0].info.creationTime == nil)
                #expect(entries[0].data == Constants.текстовыйФайлData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try ZipContainer.open(container: testData) } throws: { error in
                if case let .some(.wrongCRC(entries)) = error as? ZipError {
                    return entries.count == 1 && entries[0].info.name == "текстовый файл" && entries[0].info.type == .regular &&
                        entries[0].info.fileSystemType == .unix && entries[0].info.compressionMethod == .deflate &&
                        entries[0].info.isTextFile && entries[0].info.ownerID == 501 && entries[0].info.groupID == 20 &&
                        entries[0].info.permissions == Permissions(rawValue: 420) && entries[0].info.dosAttributes == DosAttributes(rawValue: 0) &&
                        entries[0].info.comment == "" && entries[0].info.modificationTime != nil && entries[0].info.accessTime != nil &&
                        entries[0].info.creationTime == nil && entries[0].data == Constants.текстовыйФайлData
                }
                return false
            }
        #endif
    }

}
