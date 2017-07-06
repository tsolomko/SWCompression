// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during processing TAR container.
 It may indicate that either container is damaged or it might not be TAR container at all.
 */
public enum TarError: Error {
    /// Size of data is too small, even to contain only one header.
    case tooSmallFileIsPassed
    /// Failed to process a field as a number.
    case fieldIsNotNumber
    /// Computed checksum of a header doesn't match the value stored in container.
    case wrongHeaderChecksum
    /// Unsupported version of USTAR format.
    case wrongUstarVersion
    /// Entry from PAX extended header is in incorrect format.
    case wrongPaxHeaderEntry
    /// Failed to process a field as an ASCII string.
    case notAsciiString
}
