// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

struct GzipTests {

    private static let testType: String = "gz"

    func header(test testName: String, mtime: Int) throws {
        let testData = try Constants.data(forTest: testName, withType: GzipTests.testType)
        let testGzipHeader = try GzipHeader(archive: testData)

        #expect(testGzipHeader.compressionMethod == .deflate)
        #expect(testGzipHeader.modificationTime == Date(timeIntervalSince1970: TimeInterval(mtime)))
        #expect(testGzipHeader.osType == .unix)
        #expect(testGzipHeader.fileName == "\(testName).answer")
        #expect(testGzipHeader.comment == nil)
        #expect(testGzipHeader.extraFields.isEmpty)
    }

    func unarchive(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: GzipTests.testType)
        let decompressedData = try GzipArchive.unarchive(archive: testData)

        let answerData = try Constants.data(forAnswer: testName)
        #expect(decompressedData == answerData)
    }

    func archive(test testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)

        // Options for archiving.
        let mtimeDate = Date(timeIntervalSinceNow: 0.0)
        let mtime = mtimeDate.timeIntervalSince1970.rounded(.towardZero)

        // Random extra field.
        let si1 = UInt8.random(in: 0...255)
        let si2 = UInt8.random(in: 1...255) // 0 is a reserved value here.
        let len = UInt16.random(in: 0...(UInt16.max - 4))
        var extraFieldBytes = [UInt8]()
        for _ in 0..<len {
            extraFieldBytes.append(UInt8.random(in: 0...255))
        }
        let extraField = GzipHeader.ExtraField(si1, si2, extraFieldBytes)

        // Test GZip archiving.
        let archiveData = try GzipArchive.archive(data: answerData, comment: "some file comment",
                                                  fileName: testName + ".answer", writeHeaderCRC: true,
                                                  isTextFile: true, osType: .macintosh, modificationTime: mtimeDate,
                                                  extraFields: [extraField])

        // Test output GZip header.
        let testGzipHeader = try GzipHeader(archive: archiveData)

        #expect(testGzipHeader.compressionMethod == .deflate)
        #expect(testGzipHeader.modificationTime?.timeIntervalSince1970 == mtime)
        #expect(testGzipHeader.osType == .macintosh)
        #expect(testGzipHeader.fileName == "\(testName).answer")
        #expect(testGzipHeader.comment == "some file comment")
        #expect(testGzipHeader.isTextFile)
        #expect(testGzipHeader.extraFields.count == 1)
        #expect(testGzipHeader.extraFields.first?.si1 == si1)
        #expect(testGzipHeader.extraFields.first?.si2 == si2)
        #expect(testGzipHeader.extraFields.first?.bytes == extraFieldBytes)

        // Test output GZip archive content.
        let decompressedData = try GzipArchive.unarchive(archive: archiveData)

        #expect(decompressedData == answerData)
    }

    @Test func test1() throws {
        try self.header(test: "test1", mtime: 1482698300)
        try self.unarchive(test: "test1")
    }

    @Test func test2() throws {
        try self.header(test: "test2", mtime: 1482698300)
        try self.unarchive(test: "test2")
    }

    @Test func test3() throws {
        try self.header(test: "test3", mtime: 1482698301)
        try self.unarchive(test: "test3")
    }

    @Test func test4() throws {
        try self.header(test: "test4", mtime: 1482698301)
        try self.unarchive(test: "test4")
    }

    @Test func test4ExtraField() throws {
        let testData = try Constants.data(forTest: "test4_extra_field", withType: GzipTests.testType)
        let testGzipHeader = try GzipHeader(archive: testData)

        #expect(testGzipHeader.compressionMethod == .deflate)
        #expect(testGzipHeader.modificationTime?.timeIntervalSince1970 == 1665760462)
        #expect(testGzipHeader.osType == .macintosh)
        #expect(testGzipHeader.fileName == "test4.answer")
        #expect(testGzipHeader.comment == "some file comment")
        #expect(testGzipHeader.isTextFile)
        #expect(testGzipHeader.extraFields.count == 1)
        #expect(testGzipHeader.extraFields.first?.si1 == 0x54)
        #expect(testGzipHeader.extraFields.first?.si2 == 0x53)
        #expect(testGzipHeader.extraFields.first?.bytes == [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA,
                                                            0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22, 0x33, 0x44, 0x55,
                                                            0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
    }

    @Test func test5() throws {
        try self.header(test: "test5", mtime: 1482698242)
        try self.unarchive(test: "test5")
    }

    @Test func test6() throws {
        try self.header(test: "test6", mtime: 1511554495)
        try self.unarchive(test: "test6")
    }

    @Test func test7() throws {
        try self.header(test: "test7", mtime: 1511554611)
        try self.unarchive(test: "test7")
    }

    @Test func test8() throws {
        try self.header(test: "test8", mtime: 1483040005)
        try self.unarchive(test: "test8")
    }

    @Test func test9() throws {
        try self.header(test: "test9", mtime: 1483040005)
        try self.unarchive(test: "test9")
    }

    @Test func archive4() throws {
        try self.archive(test: "test4")
    }

    @Test func multiUnarchive() throws {
        let testData = try Constants.data(forTest: "test_multi", withType: GzipTests.testType)
        let members = try GzipArchive.multiUnarchive(archive: testData)

        try #require(members.count == 4)

        for i in 1...4 {
            let header = members[i - 1].header
            #expect(header.fileName == "test\(i).answer")
            let data = members[i - 1].data

            let answerData = try Constants.data(forAnswer: "test\(i)")
            #expect(data == answerData)
        }
    }

    @Test func multiUnarchiveRedundant() throws {
        let testData = try Constants.data(forTest: "test1", withType: GzipTests.testType)
        let members = try GzipArchive.multiUnarchive(archive: testData)

        try #require(members.count == 1)

        let header = members[0].header
        #expect(header.fileName == "test1.answer")
        let data = members[0].data

        let answerData = try Constants.data(forAnswer: "test1")
        #expect(data == answerData)
    }

    @Test func shortInput() {
        #expect(throws: (any Error).self) { try GzipArchive.unarchive(archive: Data([0])) }
        #expect(throws: (any Error).self) { try GzipArchive.multiUnarchive(archive: Data([0])) }
        #expect(throws: (any Error).self) { try GzipHeader(archive: Data([0])) }
    }

    @Test func invalidInput() throws {
        let testData = try Constants.data(forAnswer: "test6")
        #expect(throws: (any Error).self) { try GzipArchive.unarchive(archive: testData) }
        #expect(throws: (any Error).self) { try GzipArchive.multiUnarchive(archive: testData) }
    }

    @Test func emptyInput() throws {
        #expect(throws: (any Error).self) { try GzipArchive.unarchive(archive: Data()) }
    }

    @Test func checksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test1", withType: GzipTests.testType)
        // Here we modify the stored value of crc32.
        testData[41] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: GzipError.self) { try GzipArchive.unarchive(archive: testData) }
            if case let .some(.wrongCRC(members)) = error {
                try #require(members.count == 1)
                let answerData = try Constants.data(forAnswer: "test1")
                #expect(members.first!.data == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try GzipArchive.unarchive(archive: testData) } throws: { error in
                if case let .some(.wrongCRC(members)) = error as? GzipError {
                    let answerData = try Constants.data(forAnswer: "test1")
                    return members.count == 1 && members.first!.data == answerData
                }
                return false
            }
        #endif
    }

    @Test func multiUnarchiveChecksumMismatch() throws {
        // Here we test that an error for checksum mismatch is thrown correctly and its associated value contains
        // expected data. We do this by programmatically adjusting the input: we change one of the bytes for the checkum,
        // which makes it incorrect.
        var testData = try Constants.data(forTest: "test_multi", withType: GzipTests.testType)
        // Here we modify the stored value of crc32.
        testData[2289] &+= 1
        #if compiler(>=6.1)
            let error = #expect(throws: GzipError.self) { try GzipArchive.multiUnarchive(archive: testData) }
            if case let .some(.wrongCRC(members)) = error {
                try #require(members.count == 2)
                var answerData = try Constants.data(forAnswer: "test1")
                #expect(members[0].data == answerData)
                answerData = try Constants.data(forAnswer: "test2")
                #expect(members[1].data == answerData)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        #else
            #expect { try GzipArchive.multiUnarchive(archive: testData) } throws: { error in
                if case let .some(.wrongCRC(members)) = error as? GzipError {
                    let answer1Data = try Constants.data(forAnswer: "test1")
                    let answer2Data = try Constants.data(forAnswer: "test2")
                    return members.count == 2 && members[0].data == answer1Data && members[1].data == answer2Data
                }
                return false
            }
        #endif
    }

    @Test func minimal() throws {
        // In this test we test several things:
        // - that the archive consisting only of the minimal header is successfully processed,
        // - that the mtime field with the value 0 correctly results in a `GzipHeader.modificationTime == nil`,
        // - that the `GzipArchive.multiUnarchive(archive:)` works on a single member archive.
        let testData = try Constants.data(forTest: "minimal", withType: GzipTests.testType)
        let members = try GzipArchive.multiUnarchive(archive: testData)
        try #require(members.count == 1)
        if let member = members.first {
            #expect(member.header.compressionMethod == .deflate)
            #expect(member.header.modificationTime == nil)
            #expect(member.header.osType == .unix)
            #expect(member.header.fileName == nil)
            #expect(member.header.comment == nil)
            #expect(!member.header.isTextFile)
            #expect(member.data == Data())
        }
    }

    @Test func headerFooterTruncation() throws {
        // In this test we check the handling of truncation inside the optional elements (name, comment, "extra field",
        // crc) of a GZip header, as well as in the "checksum" information of the archive (last 8 bytes). The sample
        // file used is "test4_extra_field" since it contains a header which utilizes all format features.
        let testData = try Constants.data(forTest: "test4_extra_field", withType: GzipTests.testType)

        // We test all possible truncation points since there are very few of them.
        // The header takes first 79 bytes.
        for truncationIndex in 1..<79 {
            #expect(throws: GzipError.self, "Header truncated at \(truncationIndex)") {
                try GzipArchive.unarchive(archive: testData[..<truncationIndex])
            }
        }

        // The checksum information takes the last 8 bytes of the archive. Again, we test truncations in all of them.
        for truncationIndex in 2..<9 {
            #expect(throws: GzipError.self, "Footer truncated at \(truncationIndex)") {
                try GzipArchive.unarchive(archive: testData[...(testData.count - truncationIndex)])
            }
        }
    }

    @Test func randomInputTruncations() throws {
        for i in 1...9 {
            let testName = "test\(i)"
            let testData = try Constants.data(forTest: testName, withType: GzipTests.testType)
            // It would be better to increase amount of different truncations tested, but we hit runtime limits in CI.
            for _ in 0..<5 {
                let truncationIndex = Int.random(in: (testData.startIndex + 1)..<testData.endIndex)
                _ = try? GzipArchive.unarchive(archive: testData[testData.startIndex..<truncationIndex])
            }
        }
    }

}
