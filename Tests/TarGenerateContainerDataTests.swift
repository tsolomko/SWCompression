// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import BitByteData
@testable import SWCompression

class TarGenerateContainerDataTests: XCTestCase {

    private typealias TarGCDTests = TarGenerateContainerDataTests

    private static let testEntryInfo: TarEntryInfo = {
        var info = TarEntryInfo(name: "symbolic-link", type: .symbolicLink)
        info.size = 4
        info.accessTime = Date(timeIntervalSinceReferenceDate: 1) // 978307201
        info.creationTime = Date(timeIntervalSinceReferenceDate: 2) // 978307202
        info.modificationTime = Date(timeIntervalSinceReferenceDate: 0) // 978307200
        info.permissions = Permissions.executeOwner
        info.permissions?.insert(Permissions.writeGroup)
        info.permissions?.insert(Permissions.readOther)
        info.ownerID = 250
        info.groupID = 250
        info.ownerUserName = "testUserName"
        info.ownerGroupName = "testGroupName"
        info.deviceMajorNumber = 1
        info.deviceMinorNumber = 2
        info.charset = "UTF-8"
        info.comment = "some comment..."
        info.linkName = "file"
        info.unknownExtendedHeaderRecords = ["SWCompression/Tests/TAR": "value"]
        return info
    }()

    func testEntryInfo() throws {
        let infoData = try TarGCDTests.testEntryInfo.generateContainerData()
        XCTAssertEqual(infoData.count, 512)

        let newInfo = try TarEntryInfo(ByteReader(data: infoData), nil, nil, nil, nil)
        XCTAssertEqual(newInfo.name, "symbolic-link")
        XCTAssertEqual(newInfo.type, .symbolicLink)
        XCTAssertEqual(newInfo.permissions?.rawValue, 84)
        XCTAssertEqual(newInfo.ownerID, 250)
        XCTAssertEqual(newInfo.groupID, 250)
        XCTAssertEqual(newInfo.size, 4)
        XCTAssertEqual(newInfo.modificationTime?.timeIntervalSince1970, 978307200)
        XCTAssertEqual(newInfo.linkName, "file")
        XCTAssertEqual(newInfo.ownerUserName, "testUserName")
        XCTAssertEqual(newInfo.ownerGroupName, "testGroupName")
        XCTAssertEqual(newInfo.deviceMajorNumber, 1)
        XCTAssertEqual(newInfo.deviceMinorNumber, 2)

        // Some properties cannot be saved with ustar format.
        XCTAssertNil(newInfo.accessTime)
        XCTAssertNil(newInfo.creationTime)
        XCTAssertNil(newInfo.charset)
        XCTAssertNil(newInfo.comment)
        XCTAssertNil(newInfo.unknownExtendedHeaderRecords)

        XCTAssertNil(newInfo.specialEntryType)
        XCTAssertEqual(newInfo.format, .ustar)
    }

}
