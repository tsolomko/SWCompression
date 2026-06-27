// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import Testing
import SWCompression

// Has to be a class for `deinit()` to work.
final class TarWriterTests {

    private let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("TestSWCompression-" + UUID().uuidString, isDirectory: true)

    init() {
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            fatalError("TarWriterTests.setUp(): unable to create temporary directory: \(error)")
        }
    }

    deinit {
        do {
            try FileManager.default.removeItem(at: tempDir)
        } catch let error {
            fatalError("TarWriterTests.tearDown(): unable to remove temporary directory: \(error)")
        }
    }

    private func generateContainerData(_ entries: [TarEntry], format: TarContainer.Format = .pax) throws -> Data {
        let tempFileUrl = tempDir.appendingPathComponent(UUID().uuidString, isDirectory: false)
        try "".write(to: tempFileUrl, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forWritingTo: tempFileUrl)
        var writer = TarWriter(fileHandle: handle, force: format)
        for entry in entries {
            try writer.append(entry)
        }
        try writer.finalize()
        try handle.close()
        return try Data(contentsOf: tempFileUrl)
    }

    @Test func test1() throws {
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.ownerUserName = "timofeysolomko"
        info.ownerGroupName = "staff"
        info.ownerID = 501
        info.groupID = 20
        info.permissions = Permissions(rawValue: 420)
        // We have to convert time interval to int, since tar can't store fractional timestamps, so we lose in accuracy.
        let intTimeInterval = Int(Date().timeIntervalSince1970)
        let date = Date(timeIntervalSince1970: Double(intTimeInterval))
        info.modificationTime = date
        info.creationTime = date
        info.accessTime = date
        info.comment = "comment"
        let data = Data("Hello, World!\n".utf8)
        let entry = TarEntry(info: info, data: data)

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newEntries = try TarContainer.open(container: containerData)

        try #require(newEntries.count == 1)
        #expect(newEntries[0].info.name == "file.txt")
        #expect(newEntries[0].info.type == .regular)
        #expect(newEntries[0].info.size == 14)
        #expect(newEntries[0].info.ownerUserName == "timofeysolomko")
        #expect(newEntries[0].info.ownerGroupName == "staff")
        #expect(newEntries[0].info.ownerID == 501)
        #expect(newEntries[0].info.groupID == 20)
        #expect(newEntries[0].info.permissions == Permissions(rawValue: 420))
        #expect(newEntries[0].info.modificationTime == date)
        #expect(newEntries[0].info.creationTime == date)
        #expect(newEntries[0].info.accessTime == date)
        #expect(newEntries[0].info.comment == "comment")
        #expect(newEntries[0].data == data)
    }

    @Test func test2() throws {
        let dict = [
            "SWCompression/Tests/TAR": "value",
            "key": "valuevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevalue22"
        ]

        var info = TarEntryInfo(name: "symbolic-link", type: .symbolicLink)
        info.accessTime = Date(timeIntervalSince1970: 1)
        info.creationTime = Date(timeIntervalSince1970: 2)
        info.modificationTime = Date(timeIntervalSince1970: 0)
        info.permissions = Permissions(rawValue: 420)
        info.permissions?.insert(.executeOwner)
        info.ownerID = 250
        info.groupID = 250
        info.ownerUserName = "testUserName"
        info.ownerGroupName = "testGroupName"
        info.deviceMajorNumber = 1
        info.deviceMinorNumber = 2
        info.charset = "UTF-8"
        info.comment = "some comment..."
        info.linkName = "file"
        info.unknownExtendedHeaderRecords = dict
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == "symbolic-link")
        #expect(newInfo.type == .symbolicLink)
        #expect(newInfo.permissions?.rawValue == 484)
        #expect(newInfo.ownerID == 250)
        #expect(newInfo.groupID == 250)
        #expect(newInfo.size == 0)
        #expect(newInfo.modificationTime?.timeIntervalSince1970 == 0)
        #expect(newInfo.linkName == "file")
        #expect(newInfo.ownerUserName == "testUserName")
        #expect(newInfo.ownerGroupName == "testGroupName")
        #expect(newInfo.deviceMajorNumber == 1)
        #expect(newInfo.deviceMinorNumber == 2)
        #expect(newInfo.accessTime?.timeIntervalSince1970 == 1)
        #expect(newInfo.creationTime?.timeIntervalSince1970 == 2)
        #expect(newInfo.charset == "UTF-8")
        #expect(newInfo.comment == "some comment...")
        #expect(newInfo.unknownExtendedHeaderRecords == dict)
    }

    @Test func longName() throws {
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "readme/", count: 15))
        info.name.append("readme.txt")
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        // This name should fit into ustar format using "prefix" field
        #expect(newInfo.name == info.name)
    }

    @Test func veryLongName() throws {
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "readme/", count: 25))
        info.name.append("readme.txt")
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == info.name)
    }

    @Test func longDirectoryName() throws {
        // Tests what happens to the filename's trailing slash when "prefix" field is used.
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "readme/", count: 15))
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == info.name)
    }

    @Test func unicode() throws {
        let date = Date(timeIntervalSince1970: 1300000)
        var info = TarEntryInfo(name: "ссылка", type: .symbolicLink)
        info.accessTime = date
        info.creationTime = date
        info.modificationTime = date
        info.permissions = Permissions(rawValue: 420)
        info.ownerID = 501
        info.groupID = 20
        info.ownerUserName = "timofeysolomko"
        info.ownerGroupName = "staff"
        info.deviceMajorNumber = 1
        info.deviceMinorNumber = 2
        info.comment = "комментарий"
        info.linkName = "путь/к/файлу"
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == "ссылка")
        #expect(newInfo.type == .symbolicLink)
        #expect(newInfo.permissions?.rawValue == 420)
        #expect(newInfo.ownerID == 501)
        #expect(newInfo.groupID == 20)
        #expect(newInfo.size == 0)
        #expect(newInfo.modificationTime?.timeIntervalSince1970 == 1300000)
        #expect(newInfo.linkName == "путь/к/файлу")
        #expect(newInfo.ownerUserName == "timofeysolomko")
        #expect(newInfo.ownerGroupName == "staff")
        #expect(newInfo.accessTime?.timeIntervalSince1970 == 1300000)
        #expect(newInfo.creationTime?.timeIntervalSince1970 == 1300000)
        #expect(newInfo.comment == "комментарий")
    }

    @Test func ustar() throws {
        // This set of settings should result in the container which uses only ustar TAR format features.
        let date = Date(timeIntervalSince1970: 1300000)
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.permissions = Permissions(rawValue: 420)
        info.ownerID = 501
        info.groupID = 20
        info.modificationTime = date
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry], format: .ustar)
        #expect(try TarContainer.formatOf(container: containerData) == .ustar)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == "file.txt")
        #expect(newInfo.type == .regular)
        #expect(newInfo.permissions?.rawValue == 420)
        #expect(newInfo.ownerID == 501)
        #expect(newInfo.groupID == 20)
        #expect(newInfo.size == 0)
        #expect(newInfo.modificationTime?.timeIntervalSince1970 == 1300000)
        #expect(newInfo.linkName == "")
        #expect(newInfo.ownerUserName == "")
        #expect(newInfo.ownerGroupName == "")
        #expect(newInfo.accessTime == nil)
        #expect(newInfo.creationTime == nil)
        #expect(newInfo.comment == nil)
    }

    @Test func negativeMtime() throws {
        let date = Date(timeIntervalSince1970: -1300000)
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.modificationTime = date
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry])
        #expect(try TarContainer.formatOf(container: containerData) == .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == "file.txt")
        #expect(newInfo.type == .regular)
        #expect(newInfo.size == 0)
        #expect(newInfo.modificationTime?.timeIntervalSince1970 == -1300000)
        #expect(newInfo.linkName == "")
        #expect(newInfo.ownerUserName == "")
        #expect(newInfo.ownerGroupName == "")
        #expect(newInfo.permissions == nil)
        #expect(newInfo.ownerID == nil)
        #expect(newInfo.groupID == nil)
        #expect(newInfo.accessTime == nil)
        #expect(newInfo.creationTime == nil)
        #expect(newInfo.comment == nil)
    }

    @Test func bigUid() throws {
        // Int.max tests that base-256 encoding of integer fields works in the edge case.
        for uid in [(1 << 32) - 1, Int.max] {
            var info = TarEntryInfo(name: "file.txt", type: .regular)
            info.ownerID = uid
            let entry = TarEntry(info: info, data: Data())

            let containerData = try generateContainerData([entry])
            #expect(try TarContainer.formatOf(container: containerData) == .pax)
            let newInfo = try TarContainer.open(container: containerData)[0].info

            #expect(newInfo.name == "file.txt")
            #expect(newInfo.type == .regular)
            #expect(newInfo.size == 0)
            #expect(newInfo.ownerID == uid)
            #expect(newInfo.linkName == "")
            #expect(newInfo.ownerUserName == "")
            #expect(newInfo.ownerGroupName == "")
            #expect(newInfo.permissions == nil)
            #expect(newInfo.groupID == nil)
            #expect(newInfo.accessTime == nil)
            #expect(newInfo.creationTime == nil)
            #expect(newInfo.modificationTime == nil)
            #expect(newInfo.comment == nil)
        }
    }

    @Test func gnuLongName() throws {
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "name/", count: 25))
        info.name.append("name.txt")
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry], format: .gnu)
        #expect(try TarContainer.formatOf(container: containerData) == .gnu)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == info.name)
    }

    @Test func gnuLongLinkName() throws {
        var info = TarEntryInfo(name: "", type: .symbolicLink)
        info.name = "link"
        info.linkName = "path/to/"
        info.linkName.append(String(repeating: "name/", count: 25))
        info.linkName.append("name.txt")
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry], format: .gnu)
        #expect(try TarContainer.formatOf(container: containerData) == .gnu)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == info.name)
    }

    @Test func gnuBothLongNames() throws {
        var info = TarEntryInfo(name: "", type: .symbolicLink)
        info.name = "path/to/"
        info.name.append(String(repeating: "name/", count: 25))
        info.name.append("name.txt")
        info.linkName = "path/to/"
        info.linkName.append(String(repeating: "link/", count: 25))
        info.linkName.append("link.txt")
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry], format: .gnu)
        #expect(try TarContainer.formatOf(container: containerData) == .gnu)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        #expect(newInfo.name == info.name)
    }

    @Test func gnuTimes() throws {
        var info = TarEntryInfo(name: "dir", type: .directory)
        info.ownerUserName = "tsolomko"
        info.ownerGroupName = "staff"
        info.ownerID = 501
        info.groupID = 20
        info.permissions = Permissions(rawValue: 420)
        // We have to convert time interval to int, since tar can't store fractional timestamps, so we lose in accuracy.
        let intTimeInterval = Int(Date().timeIntervalSince1970)
        let date = Date(timeIntervalSince1970: Double(intTimeInterval))
        info.modificationTime = date
        info.creationTime = date
        info.accessTime = date
        let entry = TarEntry(info: info, data: Data())

        let containerData = try generateContainerData([entry], format: .gnu)
        #expect(try TarContainer.formatOf(container: containerData) == .gnu)
        let newEntries = try TarContainer.open(container: containerData)

        try #require(newEntries.count == 1)
        #expect(newEntries[0].info.name == "dir")
        #expect(newEntries[0].info.type == .directory)
        #expect(newEntries[0].info.size == 0)
        #expect(newEntries[0].info.ownerUserName == "tsolomko")
        #expect(newEntries[0].info.ownerGroupName == "staff")
        #expect(newEntries[0].info.ownerID == 501)
        #expect(newEntries[0].info.groupID == 20)
        #expect(newEntries[0].info.permissions == Permissions(rawValue: 420))
        #expect(newEntries[0].info.modificationTime == date)
        #expect(newEntries[0].info.creationTime == date)
        #expect(newEntries[0].info.accessTime == date)
        #expect(newEntries[0].info.comment == nil)
    }

}
