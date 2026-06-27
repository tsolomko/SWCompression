// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct TarTests {

    private let testType: String = "tar"

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try TarContainer.open(container: Data([0, 1, 2])) }
    }

    @Test func invalidInput() throws {
        // This is potentially a misleading test, since there is no way to guarantee that a file is not a TAR container.
        // We use randomly generated data, since the 0-filled data is processed as an empty container.
        let testData = try Constants.data(forAnswer: "test7")
        #expect(throws: (any Error).self) { try TarContainer.open(container: testData) }
    }

    @Test func test() throws {
        let testData = try Constants.data(forTest: "test", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "test5.answer")
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == Data())
    }

    @Test func pax() throws {
        let testData = try Constants.data(forTest: "full_test", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .pax)

        let entries = try TarContainer.open(container: testData)

        #expect(entries.count == 5)

        for entry in entries {
            let name = entry.info.name.components(separatedBy: ".")[0]
            let answerData = try Constants.data(forAnswer: name)

            #expect(entry.data == answerData)
            #expect(entry.info.type == .regular)
            #expect(entry.info.ownerUserName == "tsolomko")
            #expect(entry.info.ownerGroupName == "tsolomko")
            #expect(entry.info.ownerID == 1001)
            #expect(entry.info.groupID == 1001)
            #expect(entry.info.permissions == Permissions(rawValue: 436))
            #expect(entry.info.comment == nil)
            // Checking times' values is a bit difficult since they are extremely precise.
            #expect(entry.info.modificationTime != nil)
            #expect(entry.info.accessTime != nil)
            #expect(entry.info.creationTime != nil)
        }
    }

    @Test func paxRecordNewline() throws {
        // In this test we check the handling of a PAX header record with a newline character inside a record value.
        let testData = try Constants.data(forTest: "test_pax_record_newline", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .pax)

        let entries = try TarContainer.open(container: testData)

        #expect(entries.count == 1)
        #expect(entries.first?.info.name == "test_file")
        #expect(entries.first?.data == Data("Hello, weird pax record value!".utf8))
        #expect(entries.first?.info.type == .regular)
        #expect(entries.first?.info.size == 30)
        #expect(entries.first?.info.accessTime == nil)
        #expect(entries.first?.info.creationTime == nil)
        #expect(entries.first?.info.modificationTime == Date(timeIntervalSince1970: 1666443016))
        #expect(entries.first?.info.permissions == Permissions(rawValue: 420))
        #expect(entries.first?.info.ownerID == 501)
        #expect(entries.first?.info.groupID == 20)
        #expect(entries.first?.info.ownerUserName == "tsolomko")
        #expect(entries.first?.info.ownerGroupName == "staff")
        #expect(entries.first?.info.deviceMajorNumber == 0)
        #expect(entries.first?.info.deviceMinorNumber == 0)
        #expect(entries.first?.info.charset == nil)
        #expect(entries.first?.info.comment == nil)
        #expect(entries.first?.info.linkName == "")
        #expect(entries.first?.info.unknownExtendedHeaderRecords?.count == 3)
        #expect(entries.first?.info.unknownExtendedHeaderRecords?["normal1"] == "test_record_value1")
        #expect(entries.first?.info.unknownExtendedHeaderRecords?["newline"] == "test1\ntest2")
        #expect(entries.first?.info.unknownExtendedHeaderRecords?["normal2"] == "test_record_value2")
    }

    @Test func formats() throws {
        let formatTestNames = ["test_gnu", "test_oldgnu", "test_pax", "test_ustar", "test_v7"]

        let answerData = try Constants.data(forAnswer: "test1")

        for testName in formatTestNames {
            let testData = try Constants.data(forTest: testName, withType: testType)

            if testName == "test_gnu" {
                #expect(try TarContainer.formatOf(container: testData) == .gnu)
            } else if testName == "test_oldgnu" {
                #expect(try TarContainer.formatOf(container: testData) == .gnu)
            } else if testName == "test_pax" {
                #expect(try TarContainer.formatOf(container: testData) == .pax)
            } else if testName == "test_ustar" {
                #expect(try TarContainer.formatOf(container: testData) == .ustar)
            } else if testName == "test_v7" {
                #expect(try TarContainer.formatOf(container: testData) == .prePosix)
            }

            let entries = try TarContainer.open(container: testData)

            try #require(entries.count == 1)
            #expect(entries[0].info.name == "test1.answer")
            #expect(entries[0].info.size == 14)
            #expect(entries[0].info.type == .regular)
            #expect(entries[0].data == answerData)
        }
    }

    @Test func longNames() throws {
        let formatTestNames = ["long_test_gnu", "long_test_oldgnu", "long_test_pax"]

        for testName in formatTestNames {
            let testData = try Constants.data(forTest: testName, withType: testType)

            if testName == "long_test_gnu" {
                #expect(try TarContainer.formatOf(container: testData) == .gnu)
            } else if testName == "long_test_oldgnu" {
                #expect(try TarContainer.formatOf(container: testData) == .gnu)
            } else if testName == "long_test_pax" {
                #expect(try TarContainer.formatOf(container: testData) == .pax)
            }

            let entries = try TarContainer.open(container: testData)

            #expect(entries.count == 6)
        }
    }

    @Test func winContainer() throws {
        let testData = try Constants.data(forTest: "test_win", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 2)

        #expect(entries[0].info.name == "dir/")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.ownerUserName == "")
        #expect(entries[0].info.ownerGroupName == "")
        #expect(entries[0].info.ownerID == 0)
        #expect(entries[0].info.groupID == 0)
        #expect(entries[0].info.permissions == Permissions(rawValue: 511))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == nil)

        #expect(entries[1].info.name == "text_win.txt")
        #expect(entries[1].info.type == .regular)
        #expect(entries[1].info.size == 15)
        #expect(entries[1].info.ownerUserName == "")
        #expect(entries[1].info.ownerGroupName == "")
        #expect(entries[1].info.ownerID == 0)
        #expect(entries[1].info.groupID == 0)
        #expect(entries[1].info.permissions == Permissions(rawValue: 511))
        #expect(entries[1].info.comment == nil)
        #expect(entries[1].data == "Hello, Windows!".data(using: .utf8))
    }

    @Test func emptyFile() throws {
        let testData = try Constants.data(forTest: "test_empty_file", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_file")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == Data())
    }

    @Test func emptyDirectory() throws {
        let testData = try Constants.data(forTest: "test_empty_dir", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_dir/")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 493))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == nil)
    }

    @Test func onlyDirectoryHeader() throws {
        // This tests the correct handling of the situation when there is nothing in the container but one basic header,
        // even no EOF marker (two blocks of zeros).
        let testData = try Constants.data(forTest: "test_only_dir_header", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "empty_dir/")
        #expect(entries[0].info.type == .directory)
        #expect(entries[0].info.size == 0)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 493))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == nil)
    }

    @Test func emptyContainer() throws {
        let testData = try Constants.data(forTest: "test_empty_cont", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .prePosix)

        let entries = try TarContainer.open(container: testData)

        #expect(entries.isEmpty)
    }

    @Test func bigContainer() throws {
        let testData = try Constants.data(forTest: "SWCompressionSourceCode", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        _ = try TarContainer.info(container: testData)
        _ = try TarContainer.open(container: testData)
    }

    @Test func unicodeUstar() throws {
        let testData = try Constants.data(forTest: "test_unicode_ustar", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .ustar)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "текстовый файл.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == Constants.текстовыйФайлData)
    }

    @Test func unicodePax() throws {
        let testData = try Constants.data(forTest: "test_unicode_pax", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .pax)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "текстовый файл.answer")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == Constants.текстовыйФайлData)
    }

    @Test func gnuIncrementalFormat() throws {
        let testData = try Constants.data(forTest: "test_gnu_inc_format", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .gnu)

        let entries = try TarContainer.open(container: testData)

        #expect(entries.count == 3)

        for entry in entries {
            #expect(entry.info.ownerID == 501)
            #expect(entry.info.groupID == 20)
            #expect(entry.info.ownerUserName == "timofeysolomko")
            #expect(entry.info.ownerGroupName == "staff")
            #expect(entry.info.accessTime != nil)
            #expect(entry.info.creationTime != nil)
        }
    }

    @Test func bigNumField() throws {
        // This file is truncated because of its size (8.6 GB): it doesn't contain any actual file data.
        let testData = try Constants.data(forTest: "test_big_num_field", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .gnu)

        let entries = try TarContainer.info(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].name == "rands")
        #expect(entries[0].type == .regular)
        #expect(entries[0].size == 8600000000)
        #expect(entries[0].ownerUserName == "timofeysolomko")
        #expect(entries[0].ownerGroupName == "staff")
        #expect(entries[0].ownerID == 501)
        #expect(entries[0].groupID == 20)
        #expect(entries[0].permissions == Permissions(rawValue: 420))
        #expect(entries[0].comment == nil)
    }

    @Test func negativeMtime() throws {
        let testData = try Constants.data(forTest: "test_negative_mtime", withType: testType)

        #expect(try TarContainer.formatOf(container: testData) == .gnu)

        let entries = try TarContainer.open(container: testData)

        try #require(entries.count == 1)
        #expect(entries[0].info.name == "file")
        #expect(entries[0].info.type == .regular)
        #expect(entries[0].info.size == 27)
        #expect(entries[0].info.ownerID == 501)
        #expect(entries[0].info.groupID == 20)
        #expect(entries[0].info.ownerUserName == "timofeysolomko")
        #expect(entries[0].info.ownerGroupName == "staff")
        #expect(entries[0].info.permissions == Permissions(rawValue: 420))
        #expect(entries[0].info.modificationTime == Date(timeIntervalSince1970: -313006414))
        #expect(entries[0].info.comment == nil)
        #expect(entries[0].data == "File with negative mtime.\n\n".data(using: .utf8))
    }

}
