//
//  TarContainer.swift
//  SWCompression
//
//  Created by Timofey Solomko on 05.05.17.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/**
 Error happened during processing TAR archive (container).
 It may indicate that either the data is damaged or it might not be TAR archive (container) at all.

 - `error`: error description.
 */
public enum TarError: Error {
    case tooSmallFileIsPassed
    case fieldIsNotNumber
    case wrongHeaderChecksum
    case wrongUstarVersion
}

/// Represents either a file or directory entry inside TAR archive.
public class TarEntry: ContainerEntry {

    /// Name of the file or directory.
    public var name: String? {
        return ""
    }

    public let mode: Int?
    public let ownerID: Int?
    public let groupID: Int?
    public let size: Int
    public let modificationTime: Int
    private let type: String? // TODO: Make enum and public.

    public let ownerUserName: String?
    public let ownerGroupName: String?
    private let deviceMajorNumber: String?
    private let deviceMinorNumber: String?

    private let fileName: String?
    private let fileNamePrefix: String?
    private let linkedFileName: String?

    private let dataObject: Data

    fileprivate init(_ data: Data, _ index: inout Int) throws {
        let blockStartIndex = index
        // File name
        fileName = data.nullEndedAsciiString(index, 100)
        index += 100

        // File mode
        mode = Int(data.nullSpaceEndedAsciiString(index, 8)!)
        index += 8

        // Owner's user ID
        ownerID = Int(data.nullSpaceEndedAsciiString(index, 8)!)
        index += 8

        // Group's user ID
        groupID = Int(data.nullSpaceEndedAsciiString(index, 8)!)
        index += 8

        // File size
        guard let octalFileSize = Int(data.nullSpaceEndedAsciiString(index, 12)!)
            else { throw TarError.fieldIsNotNumber }
        size = octalToDecimal(octalFileSize)
        index += 12

        // Modification time
        guard let octalMtime = Int(data.nullSpaceEndedAsciiString(index, 12)!)
            else { throw TarError.fieldIsNotNumber }
        modificationTime = octalToDecimal(octalMtime)
        index += 12

        // Checksum
        guard let octalChecksum = Int(data.nullSpaceEndedAsciiString(index, 8)!)
            else { throw TarError.fieldIsNotNumber }
        let checksum = octalToDecimal(octalChecksum)

        var headerDataForChecksum = data.subdata(in: blockStartIndex..<blockStartIndex + 512).toArray(type: UInt8.self)
        for i in 148..<156 {
            headerDataForChecksum[i] = 0x20
        }

        // Some implementations treat bytes as signed integers, but some don't.
        // So we check both cases, coincedence in one of them will pass the checksum test.
        let unsignedOurChecksumArray = headerDataForChecksum.map { UInt($0) }
        let signedOurChecksumArray = headerDataForChecksum.map { Int($0) }

        let unsignedOurChecksum = unsignedOurChecksumArray.reduce(0) { $0 + $1 }
        let signedOurChecksum = signedOurChecksumArray.reduce(0) { $0 + $1 }
        guard unsignedOurChecksum == UInt(checksum) || signedOurChecksum == checksum
            else { throw TarError.wrongHeaderChecksum }

        index += 8

        // File type
        type = String(bytes: [data[index]], encoding: .ascii)
        index += 1

        // Linked file name
        linkedFileName = data.nullEndedAsciiString(index, 100)
        index += 100

        let posixIndicator = String(data: data.subdata(in: 257..<263), encoding: .ascii)
        if posixIndicator == "ustar\u{00}" || posixIndicator == "ustar\u{20}" {
            index += 6

            let ustarVersion = String(data: data.subdata(in: index..<index + 2), encoding: .ascii)
            guard ustarVersion == "00" else { throw TarError.wrongUstarVersion }
            index += 2

            ownerUserName = data.nullEndedAsciiString(index, 32)
            index += 32

            ownerGroupName = data.nullEndedAsciiString(index, 32)
            index += 32

            deviceMajorNumber = data.nullSpaceEndedAsciiString(index, 8)
            index += 8

            deviceMinorNumber = data.nullSpaceEndedAsciiString(index, 8)
            index += 8

            fileNamePrefix = data.nullEndedAsciiString(index, 155)
            index += 155
        } else {
            ownerUserName = nil
            ownerGroupName = nil
            deviceMajorNumber = nil
            deviceMinorNumber = nil
            fileNamePrefix = nil
        }

        // File data
        index = blockStartIndex + 512
        self.dataObject = data.subdata(in: index..<index + size)
        index += size
        index = roundTo512(value: index)
    }

    /**
     Returns data associated with this entry.

     - Note: Returned `Data` object with the size of 0 can either indicate that the entry is an empty file
     or it is a directory.
     */
    public func data() -> Data {
        return dataObject
    }

}

/// Provides function which opens TAR archives (containers).
public class TarContainer: Container {

    public static func open(containerData data: Data) throws -> [ContainerEntry] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.tooSmallFileIsPassed }

        var output = [TarEntry]()

        var index = 0
        while true {
            // Container ends with two zero-filled records.
            if data.subdata(in: index..<index + 1024) == Data(bytes: Array(repeating: 0, count: 1024)) {
                break
            }
            output.append(try TarEntry(data, &index))
        }

        return output
    }

}

fileprivate extension Data {

    fileprivate func nullEndedBuffer(_ startIndex: Int, _ cutoff: Int) -> [UInt8] {
        var index = startIndex
        var buffer = [UInt8]()
        while true {
            if self[index] == 0 || index - startIndex >= cutoff {
                break
            }
            buffer.append(self[index])
            index += 1
        }
        return buffer
    }

    fileprivate func nullEndedAsciiString(_ startIndex: Int, _ cutoff: Int) -> String? {
        return String(bytes: self.nullEndedBuffer(startIndex, cutoff), encoding: .ascii)
    }

    fileprivate func nullSpaceEndedBuffer(_ startIndex: Int, _ cutoff: Int) -> [UInt8] {
        var index = startIndex
        var buffer = [UInt8]()
        while true {
            if self[index] == 0 || self[index] == 0x20 || index - startIndex >= cutoff {
                break
            }
            buffer.append(self[index])
            index += 1
        }
        return buffer
    }

    fileprivate func nullSpaceEndedAsciiString(_ startIndex: Int, _ cutoff: Int) -> String? {
        return String(bytes: self.nullSpaceEndedBuffer(startIndex, cutoff), encoding: .ascii)
    }

}

fileprivate func octalToDecimal(_ number: Int) -> Int {
    var octal = number
    var decimal = 0, i = 0
    while octal != 0 {
        let remainder = octal % 10
        octal /= 10
        decimal += remainder * Int(pow(8, Double(i)))
        i += 1
    }
    return decimal
}

fileprivate func roundTo512(value: Int) -> Int {
    let fractionNum = Double(value) / 512
    let roundedNum = Int(ceil(fractionNum))
    return roundedNum * 512
}
