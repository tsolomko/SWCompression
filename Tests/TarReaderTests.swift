// Copyright (c) 2022 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarReaderTests: XCTestCase {

    private static let testType: String = "tar"

    func test() throws {
        let testHandle = try Constants.handle(forTest: "test", withType: TarReaderTests.testType)
        var reader = TarReader(fileHandle: testHandle)
        let entries = [try reader.read()!]
        if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
            try testHandle.close()
        } else {
            testHandle.closeFile()
        }

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

}
