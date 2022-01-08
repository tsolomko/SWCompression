// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarWriterTests: XCTestCase {

    func test() throws {
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

        let tempFileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: false)
        try "".write(to: tempFileUrl, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forWritingTo: tempFileUrl)
        var writer = TarWriter(fileHandle: handle)
        try writer.append(entry)
        try writer.finalize()
        let containerData = try Data(contentsOf: tempFileUrl)
        XCTAssertEqual(try TarContainer.formatOf(container: containerData), .pax)
        let newEntries = try TarContainer.open(container: containerData)

        XCTAssertEqual(newEntries.count, 1)
        XCTAssertEqual(newEntries[0].info.name, "file.txt")
        XCTAssertEqual(newEntries[0].info.type, .regular)
        XCTAssertEqual(newEntries[0].info.size, 14)
        XCTAssertEqual(newEntries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(newEntries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(newEntries[0].info.ownerID, 501)
        XCTAssertEqual(newEntries[0].info.groupID, 20)
        XCTAssertEqual(newEntries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(newEntries[0].info.modificationTime, date)
        XCTAssertEqual(newEntries[0].info.creationTime, date)
        XCTAssertEqual(newEntries[0].info.accessTime, date)
        XCTAssertEqual(newEntries[0].info.comment, "comment")
        XCTAssertEqual(newEntries[0].data, data)
    }

}
