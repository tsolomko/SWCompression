// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarCreateTests: XCTestCase {

    func test() throws {
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.ownerUserName = "timofeysolomko"
        info.ownerGroupName = "staff"
        info.ownerID = 501
        info.groupID = 20
        info.permissions = Permissions(rawValue: 420)
        let date = Date()
        info.modificationTime = date
        info.creationTime = date
        info.accessTime = date
        info.comment = "comment"

        let data = "Hello, World!\n".data(using: .utf8)!
        let entry = TarEntry(info: info, data: data)
        let containerData = try TarContainer.create(from: [entry])
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
        XCTAssertEqual(newEntries[0].info.comment, "comment")
        XCTAssertEqual(newEntries[0].data, data)
    }

}
