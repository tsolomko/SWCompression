//
//  Protocols.swift
//  SWCompression
//
//  Created by Timofey Solomko on 29.10.16.
//  Copyright © 2016 Timofey Solomko. All rights reserved.
//

import Foundation

/// Abstract archive class which supports unarchiving.
public protocol Archive {

    /// Abstract unarchive function.
    static func unarchive(archiveData: Data) throws -> Data

}

/// Abstract decompression algorithm class which supports decompression.
public protocol DecompressionAlgorithm {

    /// Abstract decompress function.
    static func decompress(compressedData: Data) throws -> Data

}
