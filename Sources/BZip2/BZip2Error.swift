// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error which happened during BZip2 decompression.
 It may indicate that either data is damaged or it might not be compressed with BZip2 at all.
 */
public enum BZip2Error: Error {
    /// 'Magic' number is not 0x425a.
    case wrongMagic
    /// BZip version is not 2.
    case wrongVersion
    /// Unsupported block size (not from '0' to '9').
    case wrongBlockSize
    /// Unsupported block type (is neither 'pi' nor 'sqrt(pi)').
    case wrongBlockType
    /// Block is randomized.
    case randomizedBlock
    /// Wrong number of Huffman tables/groups (should be between 2 and 6).
    case wrongHuffmanGroups
    /// Selector is greater than the total number of Huffman tables/groups.
    case wrongSelector
    /// Wrong length of Huffman code (should be between 0 and 20).
    case wrongHuffmanCodeLength
    /// Symbol wasn't found in Huffman tree.
    case symbolNotFound
    /**
     Computed checksum of the uncompressed data does not match the value stored in the archive.
     Associated value contains the data that were successfully decompressed up to the point where the mismatch was
     detected.

     - When using `BZip2.decompress(data:)`: The associated value comes from a single BZip2 archive. If the mismatch
     happens at the final checksum verification, this is usually the entire decompressed output.

     - When using `BZip2.multiDecompress(data:)`: The input may contain several concatenated BZip2 archives. The error
     is thrown for the current archive that fails the checksum. The associated value contains only the data decompressed
     for that archive. Results from earlier archives are not included and are not returned once this error is thrown.
     */
    case wrongCRC(Data)
}
