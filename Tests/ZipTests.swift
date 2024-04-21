// Copyright (c) 2024 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    private static let testType: String = "zip"

    func testBadFile_short() {
        XCTAssertThrowsError(try ZipContainer.open(container: Data([0, 1, 2, 3, 4, 5, 6, 7])))
    }

    func testBadFile_invalid() throws {
        let testData = try Constants.data(forAnswer: "test6")
        XCTAssertThrowsError(try ZipContainer.open(container: testData))
    }

    func testEmptyData() throws {
        XCTAssertThrowsError(try ZipContainer.info(container: Data()))
        XCTAssertThrowsError(try ZipContainer.open(container: Data()))
    }

    func testBigContainer() throws {
        let testData = try Constants.data(forTest: "SWCompressionSourceCode", withType: ZipTests.testType)

        _ = try ZipContainer.open(container: testData)
    }

    func testZipCustomExtraField() throws {
        let testData = try Constants.data(forTest: "test_custom_extra_field", withType: ZipTests.testType)

        // First, we check that without enabling support for our custom extra field, ZipContainer doesn't recognize it.
        var entries = try ZipContainer.open(container: testData)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.customExtraFields.count, 0)

        // Enable support for custom extra field.
        ZipContainer.customExtraFields[0x0646] = TestZipExtraField.self

        entries = try ZipContainer.open(container: testData)
        XCTAssertEqual(entries.count, 1)

        let entry = entries[0]
        XCTAssertEqual(entry.info.customExtraFields.count, 2)

        for customExtraField in entry.info.customExtraFields {
            XCTAssertTrue(customExtraField is TestZipExtraField)
            XCTAssertEqual(customExtraField.id, TestZipExtraField.id)
            if customExtraField.size == 13 {
                XCTAssertEqual(customExtraField.location, .centralDirectory)
                XCTAssertEqual((customExtraField as? TestZipExtraField)?.helloString, "Hello, Extra!")
            } else if customExtraField.size == 20 {
                XCTAssertEqual(customExtraField.location, .localHeader)
                XCTAssertEqual((customExtraField as? TestZipExtraField)?.helloString, "Hello, Local Header!")
            } else {
                XCTFail("Wrong size for custom extra field.")
            }
        }

        // Disable support for the custom extra field, so it doesn't interfere with other tests.
        ZipContainer.customExtraFields.removeValue(forKey: 0x0646)
    }

    func testZip64() throws {
        let testData = try Constants.data(forTest: "test_zip64", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            XCTAssertEqual(entry.info.fileSystemType, .unix)
            XCTAssertNil(entry.info.ownerID)
            XCTAssertNil(entry.info.groupID)
            XCTAssertEqual(entry.info.comment, "")
            // Checking times' values is a bit difficult since they are extremely precise.
            XCTAssertNotNil(entry.info.modificationTime)
            XCTAssertNil(entry.info.accessTime)
            XCTAssertNil(entry.info.creationTime)
        }
    }

    func testDataDescriptor() throws {
        let testData = try Constants.data(forTest: "test_data_descriptor", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            XCTAssertEqual(entry.info.fileSystemType, .unix)
            XCTAssertEqual(entry.info.ownerID, 501)
            XCTAssertEqual(entry.info.groupID, 20)
            XCTAssertEqual(entry.info.comment, "")
            // Checking times' values is a bit difficult since they are extremely precise.
            XCTAssertNotNil(entry.info.modificationTime)
            XCTAssertNotNil(entry.info.accessTime)
            XCTAssertNil(entry.info.creationTime)
            if entry.info.name == "test_dir/dir_with_file/test_file" {
                XCTAssertEqual(entry.info.size, 14)
                XCTAssertEqual(entry.info.crc, 0xB4E89E84)
            } else if entry.info.name == "test_dir/random_file" {
                XCTAssertEqual(entry.info.size, 10250)
                XCTAssertEqual(entry.info.crc, 0xD888DA2E)
            }
        }
    }

    func testUnicode() throws {
        let testData = try Constants.data(forTest: "test_unicode", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "текстовый файл")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertEqual(entries[0].info.compressionMethod, .deflate)
        XCTAssertTrue(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)

        let answerData = try Constants.data(forAnswer: "текстовый файл")
        XCTAssertEqual(entries[0].data, answerData)
    }

    func testZipLZMA() throws {
        let testData = try Constants.data(forTest: "test_zip_lzma", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.compressionMethod, .lzma)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNotNil(entries[0].info.creationTime)

        let answerData = try Constants.data(forAnswer: "test4")
        XCTAssertEqual(entries[0].data, answerData)
    }

    func testZipBZip2() throws {
        let testData = try Constants.data(forTest: "test_zip_bzip2", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.compressionMethod, .bzip2)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x20))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNotNil(entries[0].info.creationTime)

        let answerData = try Constants.data(forAnswer: "test4")
        XCTAssertEqual(entries[0].data, answerData)
    }

    func testWinContainer() throws {
        let testData = try Constants.data(forTest: "test_win", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].info.name, "dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.fileSystemType, .fat)
        XCTAssertEqual(entries[0].info.compressionMethod, .copy)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 0))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x10))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNotNil(entries[0].info.creationTime)

        XCTAssertEqual(entries[0].data, nil)

        XCTAssertEqual(entries[1].info.name, "text_win.txt")
        XCTAssertEqual(entries[1].info.type, .regular)
        XCTAssertEqual(entries[1].info.size, 15)
        XCTAssertEqual(entries[1].info.dosAttributes?.contains(.directory), false)
        XCTAssertEqual(entries[1].info.fileSystemType, .fat)
        XCTAssertFalse(entries[1].info.isTextFile)
        XCTAssertNil(entries[1].info.ownerID)
        XCTAssertNil(entries[1].info.groupID)
        XCTAssertEqual(entries[1].info.permissions, Permissions(rawValue: 0))
        XCTAssertEqual(entries[1].info.dosAttributes, DosAttributes(rawValue: 0x20))
        XCTAssertEqual(entries[1].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[1].info.modificationTime)
        XCTAssertNotNil(entries[1].info.accessTime)
        XCTAssertNotNil(entries[1].info.creationTime)

        XCTAssertEqual(entries[1].data, "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        let testData = try Constants.data(forTest: "test_empty_file", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertEqual(entries[0].info.compressionMethod, .copy)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)

        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        let testData = try Constants.data(forTest: "test_empty_dir", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertEqual(entries[0].info.compressionMethod, .copy)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 493))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0x10))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)

        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        let testData = try Constants.data(forTest: "test_empty_cont", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

    func testBadCdExtTs() throws {
        // Tests ability to not crash when opening ZIP files with non well-formed Extended Timestamp extra field.
        // Such fields are sometimes present in Central Directory of ZIP files created by Finder in some versions of macOS.
        let testData = try Constants.data(forTest: "bad_cd_ext_ts", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)
        XCTAssertEqual(entries.count, 2)
        let answerData = try Constants.data(forAnswer: "test4")
        XCTAssertEqual(entries[1].data, answerData)
    }

    func testDosLatinUS() throws {
        // This test checks that CP437 encoding is correctly used when there is no indication the file name is in UTF-8.
        // We introduced several CP437-specific characters from the 0x80-0xFF range into "test1.answer" to test this.
        // Note, that we didn't used normal characters from the 0x00-0x7F range that don't match the characters from
        // UTF-8 with the same codes, since they are interpreted as control characters by Foundation.
        let testData = try Constants.data(forTest: "test_dos_latin_us", withType: ZipTests.testType)
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "teüë1.½n█wΩ±")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.compressionMethod, .copy)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0))
        XCTAssertEqual(entries[0].info.comment, "")
        // Checking times' values is a bit difficult since they are extremely precise.
        XCTAssertNotNil(entries[0].info.modificationTime)
        XCTAssertNotNil(entries[0].info.accessTime)
        XCTAssertNil(entries[0].info.creationTime)

        let answerData = try Constants.data(forAnswer: "test1")
        XCTAssertEqual(entries[0].data, answerData)
    }

    func testChecksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test_unicode", withType: ZipTests.testType)
        // Here we modify the stored value of crc32.
        testData[16] &+= 1
        var thrownError: Error? = nil
        XCTAssertThrowsError(try ZipContainer.open(container: testData)) { thrownError = $0 }
        XCTAssertTrue(thrownError is ZipError, "Unexpected error type: \(type(of: thrownError))")
        if case let .some(.wrongCRC(entries)) = thrownError as? ZipError {
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries[0].info.name, "текстовый файл")
            XCTAssertEqual(entries[0].info.type, .regular)
            XCTAssertEqual(entries[0].info.fileSystemType, .unix)
            XCTAssertEqual(entries[0].info.compressionMethod, .deflate)
            XCTAssertTrue(entries[0].info.isTextFile)
            XCTAssertEqual(entries[0].info.ownerID, 501)
            XCTAssertEqual(entries[0].info.groupID, 20)
            XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
            XCTAssertEqual(entries[0].info.dosAttributes, DosAttributes(rawValue: 0))
            XCTAssertEqual(entries[0].info.comment, "")
            // Checking times' values is a bit difficult since they are extremely precise.
            XCTAssertNotNil(entries[0].info.modificationTime)
            XCTAssertNotNil(entries[0].info.accessTime)
            XCTAssertNil(entries[0].info.creationTime)

            let answerData = try Constants.data(forAnswer: "текстовый файл")
            XCTAssertEqual(entries[0].data, answerData)
        } else {
            XCTFail("Unexpected error: \(String(describing: thrownError))")
        }
    }

}
