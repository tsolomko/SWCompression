// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
@testable import SWCompression

class TarExtendedHeaderTests: XCTestCase {

    private static let answerString = """
                        18 path=some/path
                        37 TarExtendedHeaderTests.test=value
                        """ + "\n"

    private static let longValue = """
                        valuevaluevaluevaluevaluevalue\
                        valuevaluevaluevaluevaluevalue\
                        valuevaluevaluevaluevaluevalue22
                        """

    func test() throws {
        var extHeader = TarExtendedHeader()
        extHeader.path = "some/path"
        extHeader.unknownRecords["TarExtendedHeaderTests.test"] = "value"
        let extHeaderData = try extHeader.generateContainerData()

        let extHeaderString = String(data: extHeaderData, encoding: .utf8)
        XCTAssertEqual(extHeaderString, TarExtendedHeaderTests.answerString)

        let newExtHeader = try TarExtendedHeader(extHeaderData)
        XCTAssertEqual(newExtHeader.path, "some/path")
        XCTAssertEqual(newExtHeader.unknownRecords, ["TarExtendedHeaderTests.test" : "value"])

        XCTAssertNil(newExtHeader.atime)
        XCTAssertNil(newExtHeader.charset)
        XCTAssertNil(newExtHeader.comment)
        XCTAssertNil(newExtHeader.ctime)
        XCTAssertNil(newExtHeader.gid)
        XCTAssertNil(newExtHeader.gname)
        XCTAssertNil(newExtHeader.linkpath)
        XCTAssertNil(newExtHeader.mtime)
        XCTAssertNil(newExtHeader.size)
        XCTAssertNil(newExtHeader.uid)
        XCTAssertNil(newExtHeader.uname)
    }

    func testLongValue() throws {
        var extHeader = TarExtendedHeader()
        extHeader.unknownRecords["key"] = TarExtendedHeaderTests.longValue
        let extHeaderData = try extHeader.generateContainerData()

        let newExtHeader = try TarExtendedHeader(extHeaderData)
        XCTAssertEqual(newExtHeader.unknownRecords, ["key": TarExtendedHeaderTests.longValue])

        XCTAssertNil(newExtHeader.atime)
        XCTAssertNil(newExtHeader.charset)
        XCTAssertNil(newExtHeader.comment)
        XCTAssertNil(newExtHeader.ctime)
        XCTAssertNil(newExtHeader.gid)
        XCTAssertNil(newExtHeader.gname)
        XCTAssertNil(newExtHeader.linkpath)
        XCTAssertNil(newExtHeader.mtime)
        XCTAssertNil(newExtHeader.path)
        XCTAssertNil(newExtHeader.size)
        XCTAssertNil(newExtHeader.uid)
        XCTAssertNil(newExtHeader.uname)
    }

    func testUnicode() throws {
        var extHeader = TarExtendedHeader()
        extHeader.linkpath = "какой-то путь"

        let extHeaderData = try extHeader.generateContainerData()

        let newExtHeader = try TarExtendedHeader(extHeaderData)
        XCTAssertEqual(newExtHeader.linkpath, "какой-то путь")

        XCTAssertNil(newExtHeader.atime)
        XCTAssertNil(newExtHeader.charset)
        XCTAssertNil(newExtHeader.comment)
        XCTAssertNil(newExtHeader.ctime)
        XCTAssertNil(newExtHeader.gid)
        XCTAssertNil(newExtHeader.gname)
        XCTAssertNil(newExtHeader.mtime)
        XCTAssertNil(newExtHeader.path)
        XCTAssertNil(newExtHeader.size)
        XCTAssertNil(newExtHeader.uid)
        XCTAssertNil(newExtHeader.uname)
        XCTAssertEqual(newExtHeader.unknownRecords, [:])
    }

    func testEmpty() throws {
        let extHeader = TarExtendedHeader()
        let extHeaderData = try extHeader.generateContainerData()
        let newExtHeader = try TarExtendedHeader(extHeaderData)
        XCTAssertNil(newExtHeader.linkpath)
        XCTAssertNil(newExtHeader.atime)
        XCTAssertNil(newExtHeader.charset)
        XCTAssertNil(newExtHeader.comment)
        XCTAssertNil(newExtHeader.ctime)
        XCTAssertNil(newExtHeader.gid)
        XCTAssertNil(newExtHeader.gname)
        XCTAssertNil(newExtHeader.mtime)
        XCTAssertNil(newExtHeader.path)
        XCTAssertNil(newExtHeader.size)
        XCTAssertNil(newExtHeader.uid)
        XCTAssertNil(newExtHeader.uname)
        XCTAssertEqual(newExtHeader.unknownRecords, [:])
    }

}
