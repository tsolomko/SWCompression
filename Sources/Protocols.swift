//
//  Protocols.swift
//  SWCompression
//
//  Created by Timofey Solomko on 29.10.16.
//  Copyright © 2017 Timofey Solomko. All rights reserved.
//

import Foundation

/// Abstract archive class which supports unarchiving.
public protocol Archive {

    /// Abstract unarchive function.
    static func unarchive(archive: Data) throws -> Data

}

/// Abstract decompression algorithm class which supports decompression.
public protocol DecompressionAlgorithm {

    /// Abstract decompress function.
    static func decompress(data: Data) throws -> Data

}

public protocol Container {

    static func open(container: Data) throws -> [ContainerEntry]

}

public protocol ContainerEntry {

    var name: String { get }
    var size: Int { get }
    var isDirectory: Bool { get }

    func data() throws -> Data

}
