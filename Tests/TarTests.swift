// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarTests: XCTestCase {

    private static let testType: String = "tar"

    func test() throws {
        guard let testData = Constants.data(forTest: "test", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "test5.answer")
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(entries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertNil(entries[0].info.comment)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testPax() throws {
        guard let testData = Constants.data(forTest: "full_test", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .pax)

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 5)

        for entry in entries {
            let name = entry.info.name.components(separatedBy: ".")[0]
            guard let answerData = Constants.data(forAnswer: name) else {
                XCTFail("Unable to get answer data.")
                return
            }

            XCTAssertEqual(entry.data, answerData)
            XCTAssertEqual(entry.info.type, .regular)
            XCTAssertEqual(entry.info.ownerUserName, "tsolomko")
            XCTAssertEqual(entry.info.ownerGroupName, "tsolomko")
            XCTAssertEqual(entry.info.ownerID, 1001)
            XCTAssertEqual(entry.info.groupID, 1001)
            XCTAssertEqual(entry.info.permissions, Permissions(rawValue: 436))
            XCTAssertNil(entry.info.comment)
            // Checking times' values is a bit difficult since they are extremely precise.
            XCTAssertNotNil(entry.info.modificationTime)
            XCTAssertNotNil(entry.info.accessTime)
            XCTAssertNotNil(entry.info.creationTime)
        }
    }

    func testFormats() throws {
        let formatTestNames = ["test_gnu", "test_oldgnu", "test_pax", "test_ustar", "test_v7"]

        guard let answerData = Constants.data(forAnswer: "test1") else {
            XCTFail("Unable to get answer data.")
            return
        }

        for testName in formatTestNames {
            guard let testData = Constants.data(forTest: testName, withType: TarTests.testType) else {
                XCTFail("Unable to get test data.")
                return
            }

            if testName == "test_gnu" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)
            } else if testName == "test_oldgnu" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)
            } else if testName == "test_pax" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .pax)
            } else if testName == "test_ustar" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)
            } else if testName == "test_v7" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .prePosix)
            }

            let entries = try TarContainer.open(container: testData)

            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries[0].info.name, "test1.answer")
            XCTAssertEqual(entries[0].info.size, 14)
            XCTAssertEqual(entries[0].info.type, .regular)
            XCTAssertEqual(entries[0].data, answerData)
        }
    }

    func testLongNames() throws {
        let formatTestNames = ["long_test_gnu", "long_test_oldgnu", "long_test_pax"]

        for testName in formatTestNames {
            guard let testData = Constants.data(forTest: testName, withType: TarTests.testType) else {
                XCTFail("Unable to get test data.")
                return
            }

            if testName == "long_test_gnu" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .gnu)
            } else if testName == "long_test_oldgnu" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .gnu)
            } else if testName == "long_test_pax" {
                XCTAssertEqual(try TarContainer.formatOf(container: testData), .pax)
            }

            let entries = try TarContainer.open(container: testData)

            XCTAssertEqual(entries.count, 6)
        }
    }

    func testWinContainer() throws {
        guard let testData = Constants.data(forTest: "test_win", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].info.name, "dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.ownerUserName, "")
        XCTAssertEqual(entries[0].info.ownerGroupName, "")
        XCTAssertEqual(entries[0].info.ownerID, 0)
        XCTAssertEqual(entries[0].info.groupID, 0)
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 511))
        XCTAssertNil(entries[0].info.comment)
        XCTAssertEqual(entries[0].data, nil)


        XCTAssertEqual(entries[1].info.name, "text_win.txt")
        XCTAssertEqual(entries[1].info.type, .regular)
        XCTAssertEqual(entries[1].info.size, 15)
        XCTAssertEqual(entries[1].info.ownerUserName, "")
        XCTAssertEqual(entries[1].info.ownerGroupName, "")
        XCTAssertEqual(entries[1].info.ownerID, 0)
        XCTAssertEqual(entries[1].info.groupID, 0)
        XCTAssertEqual(entries[1].info.permissions, Permissions(rawValue: 511))
        XCTAssertNil(entries[1].info.comment)
        XCTAssertEqual(entries[1].data, "Hello, Windows!".data(using: .utf8))
    }

    func testEmptyFile() throws {
        guard let testData = Constants.data(forTest: "test_empty_file", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_file")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(entries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertNil(entries[0].info.comment)
        XCTAssertEqual(entries[0].data, Data())
    }

    func testEmptyDirectory() throws {
        guard let testData = Constants.data(forTest: "test_empty_dir", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "empty_dir/")
        XCTAssertEqual(entries[0].info.type, .directory)
        XCTAssertEqual(entries[0].info.size, 0)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(entries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 493))
        XCTAssertNil(entries[0].info.comment)
        XCTAssertEqual(entries[0].data, nil)
    }

    func testEmptyContainer() throws {
        guard let testData = Constants.data(forTest: "test_empty_cont", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .prePosix)

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.isEmpty, true)
    }

    func testBigContainer() throws {
        guard let testData = Constants.data(forTest: "SWCompressionSourceCode", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        XCTAssertEqual(try TarContainer.formatOf(container: testData), .ustar)

        _ = try TarContainer.info(container: testData)
        _ = try TarContainer.open(container: testData)
    }

    func testUnicodeUstar() throws {
        guard let testData = Constants.data(forTest: "test_unicode_ustar", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "текстовый файл.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(entries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertNil(entries[0].info.comment)

        guard let answerData = Constants.data(forAnswer: "текстовый файл") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testUnicodePax() throws {
        guard let testData = Constants.data(forTest: "test_unicode_pax", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].info.name, "текстовый файл.answer")
        XCTAssertEqual(entries[0].info.type, .regular)
        XCTAssertEqual(entries[0].info.ownerID, 501)
        XCTAssertEqual(entries[0].info.groupID, 20)
        XCTAssertEqual(entries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(entries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(entries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertNil(entries[0].info.comment)

        guard let answerData = Constants.data(forAnswer: "текстовый файл") else {
            XCTFail("Unable to get answer data.")
            return
        }

        XCTAssertEqual(entries[0].data, answerData)
    }

    func testGnuIncrementalFormat() throws {
        guard let testData = Constants.data(forTest: "test_gnu_inc_format", withType: TarTests.testType) else {
            XCTFail("Unable to get test data.")
            return
        }

        let entries = try TarContainer.open(container: testData)

        XCTAssertEqual(entries.count, 3)

        for entry in entries {
            XCTAssertEqual(entry.info.ownerID, 501)
            XCTAssertEqual(entry.info.groupID, 20)
            XCTAssertEqual(entry.info.ownerUserName, "timofeysolomko")
            XCTAssertEqual(entry.info.ownerGroupName, "staff")
            XCTAssertNotNil(entry.info.accessTime)
            XCTAssertNotNil(entry.info.creationTime)
        }
    }

}
