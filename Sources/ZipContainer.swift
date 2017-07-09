// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Provides open function for ZIP containers.
public class ZipContainer: Container {

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
        let bitReader = BitReader(data: data, bitOrder: .reversed)
        var entries = [ZipEntry]()

        bitReader.index = bitReader.size - 22 // 22 is a minimum amount which could take end of CD record.
        while true {
            // Check signature.
            if bitReader.uint32() == 0x06054b50 {
                // We found it!
                break
            }
            if bitReader.index == 0 {
                throw ZipError.notFoundCentralDirectoryEnd
            }
            bitReader.index -= 5
        }

        let endOfCD = try ZipEndOfCentralDirectory(bitReader)
        let cdEntries = endOfCD.cdEntries

        // OK, now we are ready to read Central Directory itself.
        bitReader.index = Int(UInt(truncatingBitPattern: endOfCD.cdOffset))

        for _ in 0..<cdEntries {
            let cdEntry = try ZipCentralDirectoryEntry(bitReader, endOfCD.currentDiskNumber)
            entries.append(ZipEntry(cdEntry, bitReader))
        }

        return entries
    }

}
