// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides open function for ZIP containers.
public class ZipContainer: Container {

    static let cp437Encoding = CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)

    /**
     Processes ZIP container and returns an array of `ContainerEntries` (which are actually `ZipEntries`).

     - Important: The order of entries is defined by ZIP container and,
     particularly, by a creator of a given ZIP container.
     It is likely that directories will be encountered earlier than files stored in those directories,
     but one SHOULD NOT rely on any particular order.

     - Parameter container: ZIP container's data.

     - Throws: `ZipError` or any other error associated with compression type,
     depending on the type of the problem.
     It may indicate that either container is damaged or it might not be ZIP container at all.

     - Returns: Array of `ZipEntry` as an array of `ContainerEntry`.
     */
    public static func open(container data: Data) throws -> [ContainerEntry] {
        /// Object with input data which supports convenient work with bit shifts.
        let pointerData = DataWithPointer(data: data)
        var entries = [ZipEntry]()

        pointerData.index = pointerData.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            // Check signature.
            if pointerData.uint32() == 0x06054b50 {
                // We found it!
                break
            }
            if pointerData.index == 0 {
                throw ZipError.notFoundCentralDirectoryEnd
            }
            pointerData.index -= 5
        }

        let endOfCD = try ZipEndOfCentralDirectory(pointerData)
        let cdEntries = endOfCD.cdEntries

        // OK, now we are ready to read Central Directory itself.
        pointerData.index = Int(UInt(truncatingBitPattern: endOfCD.cdOffset))

        for _ in 0..<cdEntries {
            let cdEntry = try ZipCentralDirectoryEntry(pointerData, endOfCD.currentDiskNumber)
            entries.append(ZipEntry(cdEntry, pointerData))
        }

        return entries
    }

    static func isUtf8(_ bytes: [UInt8]) -> Bool {
        var codeLength = 0
        var index = 0
        var ch: UInt32 = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte <= 0x7F {
                index += 1
                continue
            }

            if byte >= 0xC2 && byte <= 0xDF {
                codeLength = 2
            } else if byte >= 0xE0 && byte <= 0xEF {
                codeLength = 3
            } else if byte >= 0xF0 && byte <= 0xF4 {
                codeLength = 4
            } else {
                return false
            }
            if index + codeLength - 1 >= bytes.count {
                return false
            }

            for i in 1..<codeLength {
                if bytes[index + i] & 0xC0 != 0x80 {
                    return false
                }
            }

            if codeLength == 2 {
                ch = ((UInt32(bytes[index]) & 0x1F) << 6) + (UInt32(bytes[index + 1]) & 0x3F)
            } else if codeLength == 3 {
                ch = ((UInt32(bytes[index]) & 0x0F) << 12) + ((UInt32(bytes[index + 1]) & 0x3F) << 6) +
                    (UInt32(bytes[index + 2]) & 0x3F)
                if ch < 0x0800 {
                    return false
                }
                if ch >> 11 == 0x1B {
                    return false
                }
            } else if codeLength == 4 {
                ch = ((UInt32(bytes[index]) & 0x07) << 18) + ((UInt32(bytes[index + 1]) & 0x3F) << 12) +
                    ((UInt32(bytes[index + 2]) & 0x3F) << 6) + (UInt32(bytes[index + 3]) & 0x3F)
                if ch < 0x10000 || ch > 0x10FFFF {
                    return false
                }
            }
            index += codeLength
        }
        return true
    }

}
