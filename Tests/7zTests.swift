// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class SevenZipTests: XCTestCase {

    private static let testType: String = "7z"

    func test1() throws {
        guard let testURL = Constants.url(forTest: "test1", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        guard let answerURL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test1.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].data, answerData)
    }

    func test2() throws {
        guard let testURL = Constants.url(forTest: "test2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        guard let answer1URL = Constants.url(forAnswer: "test1") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        var answerData = try Data(contentsOf: answer1URL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].info.name, "test1.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, answerData.count)
        XCTAssertEqual(entries[0].data, answerData)

        guard let answer4URL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        answerData = try Data(contentsOf: answer4URL, options: .mappedIfSafe)

        XCTAssertEqual(entries[1].info.name, "test4.answer")
        XCTAssertNotEqual(entries[1].info.type, .directory)
        XCTAssertEqual(entries[1].info.size, answerData.count)
        XCTAssertEqual(entries[1].data, answerData)
    }

    func test3() throws {
        guard let testURL = Constants.url(forTest: "test3", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            _ = try SevenZipContainer.open(container: testData)
        #else
            _ = try SevenZipContainer.info(container: testData)
        #endif
    }

    func testAntiFile() throws {
        guard let testURL = Constants.url(forTest: "test_anti_file", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            let entries = try SevenZipContainer.open(container: testData)

            XCTAssertEqual(entries.count, 6)

            for entry in entries {
                if entry.info.name == "test_create/test4.answer" {
                    XCTAssertEqual(entry.info.isAnti, true)
                }
            }
        #else
            let entries = try SevenZipContainer.info(container: testData)

            XCTAssertEqual(entries.count, 6)

            for entry in entries {
                if entry.name == "test_create/test4.answer" {
                    XCTAssertEqual(entry.isAnti, true)
                }
            }
        #endif
    }

    func testMultiBlocks() throws {
        // Container was created with "solid" options set to "off" (-ms=off).
        guard let testURL = Constants.url(forTest: "test_multi_blocks", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            let entries = try SevenZipContainer.open(container: testData)

            XCTAssertEqual(entries.count, 6)
        #else
            let entries = try SevenZipContainer.info(container: testData)

            XCTAssertEqual(entries.count, 6)
        #endif
    }

    func testAllTimestamps() throws {
        // Container was created with "-mtc=on" and "-mta=on" options.
        guard let testURL = Constants.url(forTest: "test_all_timestamps", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            let entries = try SevenZipContainer.open(container: testData)

            XCTAssertEqual(entries.count, 6)

            for entry in entries {
                XCTAssertNotNil(entry.info.creationTime)
                XCTAssertNotNil(entry.info.accessTime)
                // Just in case...
                XCTAssertNotNil(entry.info.modificationTime)
            }
        #else
            let entries = try SevenZipContainer.info(container: testData)

            XCTAssertEqual(entries.count, 6)

            for entry in entries {
                XCTAssertNotNil(entry.creationTime)
                XCTAssertNotNil(entry.accessTime)
                // Just in case...
                XCTAssertNotNil(entry.modificationTime)
            }
        #endif
    }

    func testComplicatedCodingScheme() throws {
        // Container was created with these options: "-mf=BCJ -m0=Copy -m1=Deflate -m2=Delta -m3=LZMA -m4=LZMA2"
        guard let testURL = Constants.url(forTest: "test_complicated_coding_scheme",
                                          withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        // In these test case the most important thing is that information about entries must be read correctly.
        _ = try SevenZipContainer.info(container: testData)

        // It is expected for `open(container:) function to throw `SevenZipError.compressionNotSupported`,
        //  because of the coders used.
        #if LONG_TESTS
            XCTAssertThrowsError(try SevenZipContainer.open(container: testData)) { error in
                XCTAssertEqual(error as? SevenZipError, SevenZipError.compressionNotSupported)
            }
        #endif
    }

    func testEncryptedHeader() throws {
        // Container was created with "-mhe=on".
        guard let testURL = Constants.url(forTest: "test_encrypted_header", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        XCTAssertThrowsError(try SevenZipContainer.info(container: testData)) { error in
            XCTAssertEqual(error as? SevenZipError, SevenZipError.encryptionNotSupported)
        }

        // There is no point in testing `open(container:)` function, because we are unable to get even files' info.
    }

    func testSingleThread() throws {
        // Container was created with disabled multithreading options.
        // We check this just in case.
        guard let testURL = Constants.url(forTest: "test_single_thread", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            let entries = try SevenZipContainer.open(container: testData)

            XCTAssertEqual(entries.count, 6)
        #else
            let entries = try SevenZipContainer.info(container: testData)

            XCTAssertEqual(entries.count, 6)
        #endif
    }

    func testBigContainer() throws {
        guard let testURL = Constants.url(forTest: "SWCompressionSourceCode", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)

        #if LONG_TESTS
            _ = try SevenZipContainer.open(container: testData)
        #else
            _ = try SevenZipContainer.info(container: testData)
        #endif
    }

    func test7zBZip2() throws {
        // File in container compressed with BZip2.
        guard let testURL = Constants.url(forTest: "test_7z_bzip2", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test7zDeflate() throws {
        // File in container compressed with Deflate.
        guard let testURL = Constants.url(forTest: "test_7z_deflate", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func test7zCopy() throws {
        // File in container is explicitly uncompressed.
        guard let testURL = Constants.url(forTest: "test_7z_copy", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test4.answer")
        XCTAssertNotEqual(entries[0].info.type, .directory)

        guard let answerURL = Constants.url(forAnswer: "test4") else {
            XCTFail("Unable to get answer's URL.")
            return
        }

        let answerData = try? Data(contentsOf: answerURL, options: .mappedIfSafe)

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testWinContainer() throws {
        guard let testURL = Constants.url(forTest: "test_win", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
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
        guard let testURL = Constants.url(forTest: "test_empty_file", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertNotEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        guard let testURL = Constants.url(forTest: "test_empty_dir", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, nil)
        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        guard let testURL = Constants.url(forTest: "test_empty_cont", withType: SevenZipTests.testType) else {
            XCTFail("Unable to get test's URL.")
            return
        }

        let testData = try Data(contentsOf: testURL, options: .mappedIfSafe)
        let entries = try SevenZipContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

}
