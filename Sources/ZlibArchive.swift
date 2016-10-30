//
//  ZlibArchive.swift
//  SWCompression
//
//  Created by Timofey Solomko on 30.10.16.
//  Copyright © 2016 tsolomko. All rights reserved.
//

import Foundation

public enum ZlibError: Error {
    case WrongCompressionMethod
    case WrongCompressionInfo
    case WrongFcheck
    case WrongCompressionLevel
}

public class ZlibArchive: Archive {

    enum CompressionLevel: Int {
        case fastestAlgorithm = 0
        case fastAlgorithm = 1
        case defaultAlgorithm = 2
        case slowAlgorithm = 3
    }

    struct ServiceInfo {
        let compressionMethod: UInt8
        let windowSize: Int
        let compressionLevel: CompressionLevel
        var startPoint: Int
    }

    static func serviceInfo(archiveData data: Data) throws -> ServiceInfo {
        // First byte is compression method and window size
        let cmf = data[0]

        // First four bits are compression method.
        // Only compression method = 8 (DEFLATE) is supported.
        let compressionMethod = convertToUInt8(uint8Array: cmf[0..<4])
        guard compressionMethod == 8 else { throw ZlibError.WrongCompressionMethod }

        // Remaining four bits indicate window size
        // For DEFLATE it must not be more than 7
        let compressionInfo = convertToUInt8(uint8Array: cmf[4..<8])
        guard compressionInfo <= 7 else { throw ZlibError.WrongCompressionInfo }
        let windowSize = Int(pow(Double(2), Double(compressionInfo + 8)))

        // Second byte is flags
        let flags = data[1]

        // Flags contain fcheck bits which are supposed to be integrity check
        guard (UInt(cmf) * 256 + UInt(flags)) % 31 == 0 else { throw ZlibError.WrongFcheck }

        // Fifth bit indicate if archive contain Adler-32 checksum of preset dictionary
        let fdict = flags[5]

        // Remaining bits indicate compression level
        guard let compressionLevel = CompressionLevel(rawValue:
            convertToInt(uint8Array: flags[6..<8])) else { throw ZlibError.WrongCompressionLevel }

        var info = ServiceInfo(compressionMethod: compressionMethod,
                               windowSize: windowSize,
                               compressionLevel: compressionLevel,
                               startPoint: 2)

        // If preset dictionary is present 4 bytes will be skipped
        if fdict == 1 {
            info.startPoint += 4
        }

        return info
    }

    // Not specification compliant because it does not checks ADLER-32 checksum and preset dicitionaries
    public static func unarchive(archiveData data: Data) throws -> Data {
        let info = try serviceInfo(archiveData: data)
        return try Deflate.decompress(compressedData: Data(data[info.startPoint..<data.count]))
    }

}
