// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZipTests: XCTestCase {

    private static let testType: String = "zip"

    func testBigContainer() throws {
        guard let testData = Constants.data(forTest: "SWCompressionSourceCode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        _ = try ZipContainer.open(container: testData)
    }

    func testZip64() throws {
        guard let testData = Constants.data(forTest: "test_zip64", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)
    }

    func testDataDescriptor() throws {
        guard let testData = Constants.data(forTest: "test_data_descriptor", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)
    }

    func testUnicode() throws {
        guard let testData = Constants.data(forTest: "test_unicode", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "текстовый файл")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertTrue(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertNotNil(entries[0].data)
    }

    func testZipLZMA() throws {
        guard let testData = Constants.data(forTest: "test_zip_lzma", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.compressionMethod, .lzma)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)

        guard let answerData = Constants.data(forAnswer: "test4") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testZipBZip2() throws {
        guard let testData = Constants.data(forTest: "test_zip_bzip2", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.compressionMethod, .bzip2)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)

        guard let answerData = Constants.data(forAnswer: "test4") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testWinContainer() throws {
        guard let testData = Constants.data(forTest: "test_win", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].info.name, "dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.dosAttributes?.contains(.directory), true)
        XCTAssertEqual(entries[0].info.fileSystemType, .fat)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)
        XCTAssertEqual(entries[0].data, nil)

        XCTAssertEqual(entries[1].info.name, "text_win.txt")
        XCTAssertEqual(entries[1].info.type, .regular)
        XCTAssertEqual(entries[1].info.size, 15)
        XCTAssertEqual(entries[1].info.dosAttributes?.contains(.directory), false)
        XCTAssertEqual(entries[1].info.fileSystemType, .fat)
        XCTAssertFalse(entries[1].info.isTextFile)
        XCTAssertNil(entries[0].info.ownerID)
        XCTAssertNil(entries[0].info.groupID)
        XCTAssertEqual(entries[1].data, "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        guard let testData = Constants.data(forTest: "test_empty_file", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        guard let testData = Constants.data(forTest: "test_empty_dir", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.fileSystemType, .unix)
        XCTAssertFalse(entries[0].info.isTextFile)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        guard let testData = Constants.data(forTest: "test_empty_cont", withType: ZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }
        let entries = try ZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

}
