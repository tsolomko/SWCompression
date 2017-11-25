// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class SevenZipTests: XCTestCase {

    private static let testType: String = "7z"

    func test1() throws {
        guard let testData = Constants.data(forTest: "test1", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        guard let answerData = Constants.data(forAnswer: "test1") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test1.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].data, answerData)
    }

    func test2() throws {
        guard let testData = Constants.data(forTest: "test2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        guard let answer1Data = Constants.data(forAnswer: "test1") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].info.name, "test1.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, answer1Data.count)
        XCTAssertEqual(entries[0].data, answer1Data)

        guard let answer4Data = Constants.data(forAnswer: "test4") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[1].info.name, "test4.answer")
        XCTAssertNotEqual(entries[1].info.type, .directory)
        XCTAssertEqual(entries[1].info.size, answer4Data.count)
        XCTAssertEqual(entries[1].data, answer4Data)
    }

    func test3() throws {
        guard let testData = Constants.data(forTest: "test3", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        _ = try SevenZipContainer.info(container: testData)
        _ = try SevenZipContainer.open(container: testData)
    }

    func testAntiFile() throws {
        guard let testData = Constants.data(forTest: "test_anti_file", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            if entry.info.name == "test_create/test4.answer" {
                XCTAssertEqual(entry.info.isAnti, true)
            }
        }
    }

    func testMultiBlocks() throws {
        // Container was created with "solid" options set to "off" (-ms=off).
        guard let testData = Constants.data(forTest: "test_multi_blocks", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)
    }

    func testAllTimestamps() throws {
        // Container was created with "-mtc=on" and "-mta=on" options.
        guard let testData = Constants.data(forTest: "test_all_timestamps", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        _ = try SevenZipContainer.info(container: testData)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 6)

        for entry in entries {
            XCTAssertNotNil(entry.info.creationTime)
            XCTAssertNotNil(entry.info.accessTime)
            // Just in case...
            XCTAssertNotNil(entry.info.modificationTime)
        }
    }

    func testComplicatedCodingScheme() throws {
        // Container was created with these options: "-mf=BCJ -m0=Copy -m1=Deflate -m2=Delta -m3=LZMA -m4=LZMA2"
        guard let testData = Constants.data(forTest: "test_complicated_coding_scheme", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        // In these test case the most important thing is that information about entries must be read correctly.
        _ = try SevenZipContainer.info(container: testData)

        // It is expected for `open(container:) function to throw `SevenZipError.compressionNotSupported`,
        //  because of the coders used.
        XCTAssertThrowsError(try SevenZipContainer.open(container: testData)) { error in
            XCTAssertEqual(error as? SevenZipError, SevenZipError.compressionNotSupported)
        }
    }

    func testEncryptedHeader() throws {
        // Container was created with "-mhe=on".
        guard let testData = Constants.data(forTest: "test_encrypted_header", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertThrowsError(try SevenZipContainer.info(container: testData)) { error in
            XCTAssertEqual(error as? SevenZipError, SevenZipError.encryptionNotSupported)
        }

        // There is no point in testing `open(container:)` function, because we are unable to get even files' info.
    }

    func testSingleThread() throws {
        // Container was created with disabled multithreading options.
        // We check this just in case.
        guard let testData = Constants.data(forTest: "test_single_thread", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try SevenZipContainer.info(container: testData).count, 6)
        XCTAssertEqual(try SevenZipContainer.open(container: testData).count, 6)
    }

    func testBigContainer() throws {
        guard let testData = Constants.data(forTest: "SWCompressionSourceCode", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        _ = try SevenZipContainer.info(container: testData)
        _ = try SevenZipContainer.open(container: testData)
    }

    func test7zBZip2() throws {
        // File in container compressed with BZip2.
        guard let testData = Constants.data(forTest: "test_7z_bzip2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)

        guard let answerData = Constants.data(forAnswer: "test4") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test7zDeflate() throws {
        // File in container compressed with Deflate.
        guard let testData = Constants.data(forTest: "test_7z_deflate", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)

        guard let answerData = Constants.data(forAnswer: "test4") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test7zCopy() throws {
        // File in container is explicitly uncompressed.
        guard let testData = Constants.data(forTest: "test_7z_copy", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)

        guard let answerData = Constants.data(forAnswer: "test4") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testWinContainer() throws {
        guard let testData = Constants.data(forTest: "test_win", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].info.name, "dir")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, nil)
        XCTAssertEqual(entries[0].data, nil)

        XCTAssertEqual(entries[1].info.name, "text_win.txt")
        XCTAssertNotEqual(entries[1].info.type, .directory)
        XCTAssertEqual(entries[1].info.size, 15)
        XCTAssertEqual(entries[1].data, "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        guard let testData = Constants.data(forTest: "test_empty_file", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertNotEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        guard let testData = Constants.data(forTest: "test_empty_dir", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, nil)
        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        guard let testData = Constants.data(forTest: "test_empty_cont", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

}
