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

}
