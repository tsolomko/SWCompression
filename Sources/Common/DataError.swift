// Copyright (c) 2021 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public enum DataError: Error {
    case truncated
    case corrupted
    case checksumMismatch([Data])
}
