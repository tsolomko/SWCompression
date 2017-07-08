// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct ZipEndOfCentralDirectory {

    /// Number of the current disk.
    private(set) var currentDiskNumber: UInt32

    /// Number of the disk with the start of CD.
    private(set) var cdDiskNumber: UInt32
    private(set) var cdEntries: UInt64
    private(set) var cdSize: UInt64
    private(set) var cdOffset: UInt64

    init(_ pointerData: DataWithPointer) throws {
        /// Indicates if Zip64 records should be present.
        var zip64RecordExists = false

        self.currentDiskNumber = pointerData.uint32FromAlignedBytes(count: 2)
        self.cdDiskNumber = pointerData.uint32FromAlignedBytes(count: 2)
        guard self.currentDiskNumber == self.cdDiskNumber
            else { throw ZipError.multiVolumesNotSupported }

        /// Number of CD entries on the current disk.
        var cdEntriesCurrentDisk = pointerData.uint64FromAlignedBytes(count: 2)
        /// Total number of CD entries.
        self.cdEntries = pointerData.uint64FromAlignedBytes(count: 2)
        guard cdEntries == cdEntriesCurrentDisk
            else { throw ZipError.multiVolumesNotSupported }

        /// Size of Central Directory.
        self.cdSize = pointerData.uint64FromAlignedBytes(count: 4)
        /// Offset to the start of Central Directory.
        self.cdOffset = pointerData.uint64FromAlignedBytes(count: 4)
        let zipCommentLength = pointerData.intFromAlignedBytes(count: 2)

        // Check if zip64 records are present.
        if self.currentDiskNumber == 0xFFFF || self.cdDiskNumber == 0xFFFF ||
            cdEntriesCurrentDisk == 0xFFFF || self.cdEntries == 0xFFFF ||
            self.cdSize == 0xFFFFFFFF || self.cdOffset == 0xFFFFFFFF {
            zip64RecordExists = true
        }

        // There is also a .ZIP file comment, but we don't need it.
        // Here's how it can be processed:
        // let zipComment = String(data: Data(bytes: pointerData.alignedBytes(count: zipCommentLength)),
        //                         encoding: .utf8)

        if zip64RecordExists { // We need to find Zip64 end of CD locator.
            // Back to start of end of CD record.
            pointerData.index -= zipCommentLength + 22
            // Zip64 locator takes exactly 20 bytes.
            pointerData.index -= 20

            // Check signature.
            guard pointerData.uint32FromAlignedBytes(count: 4) == 0x07064b50
                else { throw ZipError.wrongSignature }

            let zip64CDStartDisk = pointerData.uint32FromAlignedBytes(count: 4)
            guard self.currentDiskNumber == zip64CDStartDisk
                else { throw ZipError.multiVolumesNotSupported }

            let zip64CDEndOffset = pointerData.uint64FromAlignedBytes(count: 8)
            let totalDisks = pointerData.uint64FromAlignedBytes(count: 1)
            guard totalDisks == 1
                else { throw ZipError.multiVolumesNotSupported }

            // Now we need to move to Zip64 End of CD.
            pointerData.index = Int(UInt(truncatingBitPattern: zip64CDEndOffset))

            // Check signature.
            guard pointerData.uint32FromAlignedBytes(count: 4) == 0x06064b50
                else { throw ZipError.wrongSignature }

            // Following 8 bytes are size of end of zip64 CD, but we don't need it.
            _ = pointerData.uint64FromAlignedBytes(count: 8)

            // Next two bytes are version of compressor, but we don't need it.
            _ = pointerData.uint64FromAlignedBytes(count: 2)
            let versionNeeded = pointerData.uint64FromAlignedBytes(count: 2)
            guard versionNeeded & 0xFF <= 63
                else { throw ZipError.wrongVersion }

            // Update values read from basic End of CD with the ones from Zip64 End of CD.
            self.currentDiskNumber = pointerData.uint32FromAlignedBytes(count: 4)
            self.cdDiskNumber = pointerData.uint32FromAlignedBytes(count: 4)
            guard currentDiskNumber == cdDiskNumber
                else { throw ZipError.multiVolumesNotSupported }

            cdEntriesCurrentDisk = pointerData.uint64FromAlignedBytes(count: 8)
            self.cdEntries = pointerData.uint64FromAlignedBytes(count: 8)
            guard cdEntries == cdEntriesCurrentDisk
                else { throw ZipError.multiVolumesNotSupported }

            self.cdSize = pointerData.uint64FromAlignedBytes(count: 8)
            self.cdOffset = pointerData.uint64FromAlignedBytes(count: 8)

            // Then, there might be 'zip64 extensible data sector' with 'special purpose data'.
            // But we don't need them currently, so let's skip them.
            
            // To find the size of these data:
            // let specialPurposeDataSize = zip64EndCDSize - 56
        }
    }
    
}
