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
    case TooSmallFileIsPassed
    case FieldIsNotNumber
    case WrongHeaderChecksum
    case WrongUstarVersion
}

public class TarContainer {

    enum TarType {
        case prePOSIX
        case ustar // aka POSIX.
        case pax // TODO: Implement
    }

    public static func files(from data: Data) throws -> [Data] {
        // First, if the TAR container contains only header, it should be at least 512 bytes long.
        // So we have to check this.
        guard data.count >= 512 else { throw TarError.TooSmallFileIsPassed }

        // Then, we need to find out, if the container is POSIX or not.
        // POSIX containers have a 'ustar\x00' (or 'ustar\x20') indicator at offset 257.
        let posixIndicator = String(data: data.subdata(in: 257..<263), encoding: .ascii)
//        if posixIndicator == "ustar\u{00}" || posixIndicator == "ustar\u{20}" {
//            return try parseUstar(data)
//        } else {
//            return try parsePrePosix(data)
//        }

        var output = [Data]()

        var index = 0
        var blockStartIndex = 0
        while true {
            // Container ends with two zero-filled records.
            if data.subdata(in: index..<index + 1024) == Data(bytes: Array(repeating: 0, count: 1024)) {
                break
            }

            // File name
            let fileName = data.nullEndedAsciiString(index, 100)
            index += 100

            // File mode
            let fileMode = Int(data.nullSpaceEndedAsciiString(index, 8)!)
            index += 8

            // Owner's user ID
            let ownerID = Int(data.nullSpaceEndedAsciiString(index, 8)!)
            index += 8

            // Group's user ID
            let groupID = Int(data.nullSpaceEndedAsciiString(index, 8)!)
            index += 8

            // File size
            guard let octalFileSize = Int(data.nullSpaceEndedAsciiString(index, 12)!)
                else { throw TarError.FieldIsNotNumber }
            let fileSize = octalToDecimal(octalFileSize)
            index += 12

            // Modification time
            guard let octalMtime = Int(data.nullSpaceEndedAsciiString(index, 12)!)
                else { throw TarError.FieldIsNotNumber }
            let mtime = octalToDecimal(octalMtime)
            index += 12

            // Checksum
            guard let octalChecksum = Int(data.nullSpaceEndedAsciiString(index, 8)!)
                else { throw TarError.FieldIsNotNumber }
            let checksum = octalToDecimal(octalChecksum)

            var headerDataForChecksum = data.subdata(in: blockStartIndex..<blockStartIndex + 512).toArray(type: UInt8.self)
            for i in 148..<156 {
                headerDataForChecksum[i] = 0x20
            }

            // Some implementations treat bytes as signed integers, but some don't.
            // So we check both case, coincedence in one of them will pass the checksum test.
            let unsignedOurChecksumArray = headerDataForChecksum.map { UInt($0) }
            let signedOurChecksumArray = headerDataForChecksum.map { Int($0) }

            let unsignedOurChecksum = unsignedOurChecksumArray.reduce(0) { $0 + $1 }
            let signedOurChecksum = signedOurChecksumArray.reduce(0) { $0 + $1 }
            guard unsignedOurChecksum == UInt(checksum) || signedOurChecksum == checksum
                else { throw TarError.WrongHeaderChecksum }

            index += 8

            // File type
            let fileType = String(bytes: [data[index]], encoding: .ascii)
            index += 1

            // Linked file name
            let linkedFileName = data.nullEndedAsciiString(index, 100)
            index += 100

            if posixIndicator == "ustar\u{00}" || posixIndicator == "ustar\u{20}" {
                index += 6

                let ustarVersion = String(data: data.subdata(in: index..<index + 2), encoding: .ascii)
                guard ustarVersion == "00" else { throw TarError.WrongUstarVersion }
                index += 2

                let ownerUserName = data.nullEndedAsciiString(index, 32)
                index += 32

                let ownerGroupName = data.nullEndedAsciiString(index, 32)
                index += 32

                let deviceMajorNumber = data.nullSpaceEndedAsciiString(index, 8)
                index += 8

                let deviceMinorNumber = data.nullSpaceEndedAsciiString(index, 8)
                index += 8

                let fileNamePrefix = data.nullEndedAsciiString(index, 155)
                index += 155
            }

            // File data
            index = blockStartIndex + 512
            output.append(data.subdata(in: index..<index + fileSize))

            index += fileSize
            index = roundTo512(value: index)

            blockStartIndex = index
        }

        return output
    }

//    static func parsePrePosix(_ data: Data) throws -> [Data] {
//        return []
//    }

//    static func parseUstar(_ data: Data) throws -> [Data] {
//        return []
//    }

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
