// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct TarReaderTests {

    private let testType: String = "tar"

    @Test func invalidInput() throws {
        // This is potentially a misleading test, since there is no way to guarantee that a file is not a TAR container.
        // We use randomly generated data, since the 0-filled data is processed as an empty container.
        let testHandle = try Constants.handle(forTest: "test7", withType: "answer")
        var reader = TarReader(fileHandle: testHandle)
        #expect(throws: (any Error).self) { try reader.read() }
        try testHandle.close()
    }

    @Test func test() throws {
        let testHandle = try Constants.handle(forTest: "test", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        var isFinished = false
        var entriesCount = 0
        while !isFinished {
            isFinished = try reader.process { (entry: TarEntry?) -> Bool in
                if entry == nil {
                    return true
                }
                #expect(entry!.info.name == "test5.answer")
                #expect(entry!.info.size == 0)
                #expect(entry!.info.type == .regular)
                #expect(entry!.info.ownerID == 501)
                #expect(entry!.info.groupID == 20)
                #expect(entry!.info.ownerUserName == "timofeysolomko")
                #expect(entry!.info.ownerGroupName == "staff")
                #expect(entry!.info.permissions == Permissions(rawValue: 420))
                #expect(entry!.info.comment == nil)
                #expect(entry!.data == Data())
                entriesCount += 1
                return false
            }
        }
        #expect(entriesCount == 1)
        try testHandle.close()
    }


    @Test func pax() throws {
        let testHandle = try Constants.handle(forTest: "full_test", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        var isFinished = false
        var entriesCount = 0
        while !isFinished {
            isFinished = try reader.process { (entry: TarEntry?) -> Bool in
                if entry == nil {
                    return true
                }
                let name = entry!.info.name.components(separatedBy: ".")[0]
                let answerData = try Constants.data(forAnswer: name)
                #expect(entry!.data == answerData)
                #expect(entry!.info.type == .regular)
                #expect(entry!.info.ownerUserName == "tsolomko")
                #expect(entry!.info.ownerGroupName == "tsolomko")
                #expect(entry!.info.ownerID == 1001)
                #expect(entry!.info.groupID == 1001)
                #expect(entry!.info.permissions == Permissions(rawValue: 436))
                #expect(entry!.info.comment == nil)
                // Checking times' values is a bit difficult since they are extremely precise.
                #expect(entry!.info.modificationTime != nil)
                #expect(entry!.info.accessTime != nil)
                #expect(entry!.info.creationTime != nil)
                entriesCount += 1
                return false
            }
        }
        #expect(entriesCount == 5)
        try testHandle.close()
    }

    @Test func formats() throws {
        let formatTestNames = ["test_gnu", "test_oldgnu", "test_pax", "test_ustar", "test_v7"]
        let answerData = try Constants.data(forAnswer: "test1")

        for testName in formatTestNames {
            let testHandle = try Constants.handle(forTest: testName, withType: testType)
            var reader = TarReader(fileHandle: testHandle)
            var isFinished = false
            var entriesCount = 0
            while !isFinished {
                isFinished = try reader.process { (entry: TarEntry?) -> Bool in
                    if entry == nil {
                        return true
                    }
                    #expect(entry!.info.name == "test1.answer")
                    #expect(entry!.info.size == 14)
                    #expect(entry!.info.type == .regular)
                    #expect(entry!.data == answerData)
                    entriesCount += 1
                    return false
                }
            }
            #expect(entriesCount == 1)
            #expect(try reader.read() == nil)
            try testHandle.close()
        }
    }

    @Test func longNames() throws {
        let formatTestNames = ["long_test_gnu", "long_test_oldgnu", "long_test_pax"]
        for testName in formatTestNames {
            let testHandle = try Constants.handle(forTest: testName, withType: testType)
            var reader = TarReader(fileHandle: testHandle)
            var isFinished = false
            var entriesCount = 0
            while !isFinished {
                isFinished = try reader.process { (entry: TarEntry?) -> Bool in
                    if entry == nil {
                        return true
                    }
                    entriesCount += 1
                    return false
                }
            }
            #expect(entriesCount == 6)
            #expect(try reader.read() == nil)
            try testHandle.close()
        }
    }

    @Test func winContainer() throws {
        let testHandle = try Constants.handle(forTest: "test_win", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "dir/")
            #expect(entry!.info.type == .directory)
            #expect(entry!.info.size == 0)
            #expect(entry!.info.ownerUserName == "")
            #expect(entry!.info.ownerGroupName == "")
            #expect(entry!.info.ownerID == 0)
            #expect(entry!.info.groupID == 0)
            #expect(entry!.info.permissions == Permissions(rawValue: 511))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == nil)
        }
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "text_win.txt")
            #expect(entry!.info.type == .regular)
            #expect(entry!.info.size == 15)
            #expect(entry!.info.ownerUserName == "")
            #expect(entry!.info.ownerGroupName == "")
            #expect(entry!.info.ownerID == 0)
            #expect(entry!.info.groupID == 0)
            #expect(entry!.info.permissions == Permissions(rawValue: 511))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == "Hello, Windows!".data(using: .utf8))
        }
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func emptyFile() throws {
        let testHandle = try Constants.handle(forTest: "test_empty_file", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "empty_file")
            #expect(entry!.info.type == .regular)
            #expect(entry!.info.size == 0)
            #expect(entry!.info.ownerID == 501)
            #expect(entry!.info.groupID == 20)
            #expect(entry!.info.ownerUserName == "timofeysolomko")
            #expect(entry!.info.ownerGroupName == "staff")
            #expect(entry!.info.permissions == Permissions(rawValue: 420))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == Data())

        }
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func emptyDirectory() throws {
        let testHandle = try Constants.handle(forTest: "test_empty_dir", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "empty_dir/")
            #expect(entry!.info.type == .directory)
            #expect(entry!.info.size == 0)
            #expect(entry!.info.ownerID == 501)
            #expect(entry!.info.groupID == 20)
            #expect(entry!.info.ownerUserName == "timofeysolomko")
            #expect(entry!.info.ownerGroupName == "staff")
            #expect(entry!.info.permissions == Permissions(rawValue: 493))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == nil)
        }
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func onlyDirectoryHeader() throws {
        // This tests the correct handling of the situation when there is nothing in the container but one basic header,
        // even no EOF marker (two blocks of zeros).
        let testHandle = try Constants.handle(forTest: "test_only_dir_header", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "empty_dir/")
            #expect(entry!.info.type == .directory)
            #expect(entry!.info.size == 0)
            #expect(entry!.info.ownerID == 501)
            #expect(entry!.info.groupID == 20)
            #expect(entry!.info.ownerUserName == "timofeysolomko")
            #expect(entry!.info.ownerGroupName == "staff")
            #expect(entry!.info.permissions == Permissions(rawValue: 493))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == nil)
        }
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func emptyContainer() throws {
        let testHandle = try Constants.handle(forTest: "test_empty_cont", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func bigContainer() throws {
        let testHandle = try Constants.handle(forTest: "SWCompressionSourceCode", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        while try reader.read() != nil { }
        try testHandle.close()
    }

    @Test func unicodeUstar() throws {
        let testHandle = try Constants.handle(forTest: "test_unicode_ustar", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "текстовый файл.answer")
            #expect(entry!.info.type == .regular)
            #expect(entry!.info.ownerID == 501)
            #expect(entry!.info.groupID == 20)
            #expect(entry!.info.ownerUserName == "timofeysolomko")
            #expect(entry!.info.ownerGroupName == "staff")
            #expect(entry!.info.permissions == Permissions(rawValue: 420))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == Constants.текстовыйФайлData)

        }
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func unicodePax() throws {
        let testHandle = try Constants.handle(forTest: "test_unicode_pax", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "текстовый файл.answer")
            #expect(entry!.info.type == .regular)
            #expect(entry!.info.ownerID == 501)
            #expect(entry!.info.groupID == 20)
            #expect(entry!.info.ownerUserName == "timofeysolomko")
            #expect(entry!.info.ownerGroupName == "staff")
            #expect(entry!.info.permissions == Permissions(rawValue: 420))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == Constants.текстовыйФайлData)

        }
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    @Test func gnuIncrementalFormat() throws {
        let testHandle = try Constants.handle(forTest: "test_gnu_inc_format", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        var isFinished = false
        var entriesCount = 0
        while !isFinished {
            isFinished = try reader.process { (entry: TarEntry?) -> Bool in
                if entry == nil {
                    return true
                }
                #expect(entry!.info.ownerID == 501)
                #expect(entry!.info.groupID == 20)
                #expect(entry!.info.ownerUserName == "timofeysolomko")
                #expect(entry!.info.ownerGroupName == "staff")
                #expect(entry!.info.accessTime != nil)
                #expect(entry!.info.creationTime != nil)
                entriesCount += 1
                return false
            }
        }
        #expect(entriesCount == 3)
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

    // This test is impossible to implement using TarReader since the test file doesn't contain actual entry data.
    // @Test func bigNumField() throws { }

    @Test func negativeMtime() throws {
        let testHandle = try Constants.handle(forTest: "test_negative_mtime", withType: testType)
        var reader = TarReader(fileHandle: testHandle)
        try reader.process { (entry: TarEntry?) in
            try #require(entry != nil)
            #expect(entry!.info.name == "file")
            #expect(entry!.info.type == .regular)
            #expect(entry!.info.size == 27)
            #expect(entry!.info.ownerID == 501)
            #expect(entry!.info.groupID == 20)
            #expect(entry!.info.ownerUserName == "timofeysolomko")
            #expect(entry!.info.ownerGroupName == "staff")
            #expect(entry!.info.permissions == Permissions(rawValue: 420))
            #expect(entry!.info.modificationTime == Date(timeIntervalSince1970: -313006414))
            #expect(entry!.info.comment == nil)
            #expect(entry!.data == "File with negative mtime.\n\n".data(using: .utf8))
        }
        // Test that reading after reaching EOF returns nil.
        #expect(try reader.read() == nil)
        try testHandle.close()
    }

}
