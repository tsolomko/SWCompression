// Copyright (c) 2024 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error which happened while processing a TAR container.
 It may indicate that either container is damaged or it might not be TAR container at all.
 */
public enum TarError: Error {
    /// Data is unexpectedly truncated.
    case tooSmallFileIsPassed
    /// Failed to process a *required* TAR header's field.
    case wrongField
    /// Computed checksum of a header doesn't match the value stored in container.
    case wrongHeaderChecksum
    /// Entry from PAX extended header is in incorrect format.
    case wrongPaxHeaderEntry
}
