// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that represents an archive.
public protocol Archive {

    /// Unarchive data from the archive.
    static func unarchive(archive: Data) throws -> Data

}

/// A type that provides an implementation of a particular decompression algorithm.
public protocol DecompressionAlgorithm {

    /// Decompress data compressed with particular algorithm.
    static func decompress(data: Data) throws -> Data

}

/// A type that provides an implementation of a particular compression algorithm.
public protocol CompressionAlgorithm {

    /// Compress data with particular algorithm.
    static func compress(data: Data) throws -> Data

}

public protocol Container {

    associatedtype Entry: ContainerEntry

    static func open(container: Data) throws -> [Entry]

    static func info(container: Data) throws -> [Entry.Info]

}

public protocol ContainerEntry {

    associatedtype Info: ContainerEntryInfo

    var info: Info { get }

    var data: Data? { get }

}

public protocol ContainerEntryInfo {

    var name: String { get }

    var size: Int { get }

    var type: ContainerEntryType { get }

}

public enum ContainerEntryType {

}
