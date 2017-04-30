//
//  GzipTests.swift
//  SWCompression
//
//  Created by Timofey Solomko on 14.11.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import XCTest
import SWCompression

class GzipTests: XCTestCase {

    func perform(test testName: String, mtime: Date) {
        // Loading archive.
        guard let archiveData = try? Data(contentsOf: Constants.url(forTest: testName,
                                                                 withType: "gz"),
                                       options: .mappedIfSafe) else {
                                        XCTFail("Failed to load test archive")
                                        return
        }

        // Test GZip header parsing
        guard let testGzipHeader = try? GzipHeader(archiveData: archiveData) else {
            XCTFail("Failed to get archive header")
            return
        }

        XCTAssertEqual(testGzipHeader.compressionMethod, .deflate, "Incorrect compression method")
        XCTAssertEqual(testGzipHeader.modificationTime, mtime, "Incorrect mtime")
        XCTAssertEqual(testGzipHeader.osType, .unix, "Incorrect os type")
        XCTAssertEqual(testGzipHeader.originalFileName, "\(testName).answer", "Incorrect original file name")
        XCTAssertEqual(testGzipHeader.comment, nil, "Incorrect comment")

        // Test GZip unarchiving.
        let decompressedData = try? GzipArchive.unarchive(archiveData: archiveData)

        guard decompressedData != nil  else {
            XCTFail("Failed to decompress")
            return
        }

        guard let answerData = try? Data(contentsOf: Constants.url(forAnswer: testName)) else {
            XCTFail("Failed to get the answer")
            return
        }

        XCTAssertEqual(decompressedData, answerData, "Decompression was incorrect")

        #if PERF_TESTS
            print("Performing performance tests for gz.\(testName)")
            self.measure {
                _ = try? Deflate.decompress(compressedData: testData)
            }
        #endif
    }

    func testGzip1() {
        self.perform(test: "test1",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698300)))
    }

    func testGzip2() {
        self.perform(test: "test2",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698300)))
    }

    func testGzip3() {
        self.perform(test: "test3",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698301)))
    }

    func testGzip4() {
        self.perform(test: "test4",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698301)))
    }

    func testGzip5() {
        self.perform(test: "test5",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698242)))
    }

    func testGzip6() {
        self.perform(test: "test6",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698305)))
    }

    func testGzip7() {
        self.perform(test: "test7",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1482698304)))
    }

    func testGzip8() {
        self.perform(test: "test8",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1483040005)))
    }

    func testGzip9() {
        self.perform(test: "test9",
                     mtime: Date(timeIntervalSince1970: TimeInterval(1483040005)))
    }


}
